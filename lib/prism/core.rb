# frozen_string_literal: true

require 'octokit'
require "English"

def Prism.die(message, status = 1)
  warn message.red
  exit status
end

def Prism.create_github_client
  Octokit::Client.new(auto_traversal: true)
end

def Prism.get_crash_report(sha)
  puts "getting crash report #{sha.magenta} from cache" if @config[:verbose]
  crash_report = get_gist_from_cache(sha)
  return crash_report unless crash_report.nil?

  puts "no cache hit => reading #{sha.magenta} from github" if @config[:verbose]
  github = create_github_client
  begin
    gist = github.gist(sha)
    # this is fragile, we want to get first file from files
    # unfortunately uderlying objects are not hashes, but Sawyer::Resource
    key = gist.files.fields.to_a[0] # first file key
    crash_report = gist.files[key].content
  rescue
    puts "failed to read #{sha.magenta} from github" if @config[:verbose]
    return
  end

  puts "storing #{sha.magenta} into cache" if @config[:verbose]
  store_gist_to_cache(sha, crash_report)

  puts '---' if @config[:verbose]
  crash_report
end

def Prism.clear_caches
  clear_gist_cache
  clear_dwarfs_cache
  clear_work_dir
end

# module name is lowercase last part of the identifier, eg. totalkit or dockprogressbar
def Prism.module_id_to_name(module_id)
  module_id.strip.downcase.split('.').last
end

def Prism.lookup_module_load_address(module_name, crash_report)
  # rubocop:disable LineLength
  # 0x10c0f7000 -        0x10c110fff +com.binaryage.totalfinder.totalkit (1.4.10 - 1.4.10) <8C8578E2-CE9F-3BDE-AAE0-AB8865CA0F53> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/Frameworks/TotalKit.framework/Versions/A/TotalKit
  # 0x10c11d000 -        0x10c13bfff +com.binaryage.totalfinder.sparkle (1.4.10 - 1.4.10) <3CC42B31-1E28-3CFB-9E47-AFDA0D5B7D80> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/Frameworks/Sparkle.framework/Versions/A/Sparkle
  # 0x10c156000 -        0x10c178ff7 +com.binaryage.totalfinder.bakit (1.4.10 - 1.4.10) <02F736F5-0C30-3DF7-8830-0FB806AA47DF> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/Frameworks/BAKit.framework/Versions/A/BAKit
  # 0x10c4c9000 -        0x10c4d3ff7 +com.binaryage.totalfinder.dockprogressbar (1.4.10 - 1.4.10) <1BFC1C8D-E4FB-3833-BF2D-86717235EC55> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/PlugIns/DockProgressBar.bundle/Contents/MacOS/DockProgressBar
  # rubocop:enable LineLength

  address = nil
  crash_report.scan /^\s*([xa-fA-F\d]+)\s*-\s*([xa-fA-F\d]+)\s+\+(.*?)\s+\((.*?)\).*$/ do |_|
    address = Regexp.last_match(1).strip if module_id_to_name(Regexp.last_match(3)) == module_name
  end
  address
end

def Prism.lookup_module_version(module_name, crash_report)
  # rubocop:disable LineLength
  # 0x10c0f7000 -        0x10c110fff +com.binaryage.totalfinder.totalkit (1.4.10 - 1.4.10) <8C8578E2-CE9F-3BDE-AAE0-AB8865CA0F53> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/Frameworks/TotalKit.framework/Versions/A/TotalKit
  # 0x10c11d000 -        0x10c13bfff +com.binaryage.totalfinder.sparkle (1.4.10 - 1.4.10) <3CC42B31-1E28-3CFB-9E47-AFDA0D5B7D80> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/Frameworks/Sparkle.framework/Versions/A/Sparkle
  # 0x10c156000 -        0x10c178ff7 +com.binaryage.totalfinder.bakit (1.4.10 - 1.4.10) <02F736F5-0C30-3DF7-8830-0FB806AA47DF> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/Frameworks/BAKit.framework/Versions/A/BAKit
  # 0x10c4c9000 -        0x10c4d3ff7 +com.binaryage.totalfinder.dockprogressbar (1.4.10 - 1.4.10) <1BFC1C8D-E4FB-3833-BF2D-86717235EC55> /Library/ScriptingAdditions/TotalFinder.osax/Contents/Resources/TotalFinder.bundle/Contents/PlugIns/DockProgressBar.bundle/Contents/MacOS/DockProgressBar
  # rubocop:enable LineLength

  version = nil
  crash_report.scan /^\s*([xa-fA-F\d]+)\s*-\s*([xa-fA-F\d]+)\s+\+(.*?)\s+\((.*?)\).*$/ do |_|
    version = Regexp.last_match(4).split('-')[0].strip if module_id_to_name(Regexp.last_match(3)) == module_name
  end
  version
end

def score(x)
  case x
  when 'app'
    1
  when 'osax'
    2
  else
    0
  end
end

def Prism.dsym_path(module_id, version)
  module_name = module_id_to_name(module_id)
  dwarfs = get_dwarfs(version) # if not cached, downloads proper version from github

  candidates = []
  Dir.glob(File.join(dwarfs, '*.dSYM')) do |dsym|
    base = File.basename dsym
    # base is something like: BAKit.framework.dSYM or ColorfulSidebar.bundle.dSYM
    name_parts = base.downcase.split('.')
    name = name_parts.first
    ext = name_parts[-2]

    if module_name == name
      dsym_path = File.join(dwarfs, base)
      candidates << [dsym_path, ext]
    end
  end

  candidates.sort! do |a, b|
    score(a.second) <=> score(b.second)
  end

  # we have possible ambiguity here between TotalFinder shell, TotalFinder app and TotalFinder osax
  # HACK: sort app/osax stuff last because a crash in shell is most likely
  die "unable to lookup DSYM for module '#{module_name}@#{version}'" if candidates.first.nil?

  # dsym_path is something like "/Users/darwin/code/totalfinder/archive/dwarfs/Tabs.bundle.dSYM"
  # find first DWARF/something file in the subdirectory tree
  dsym_path = candidates.first.first
  Dir.glob(File.join(dsym_path, '**', 'DWARF', '*'))[0]
  # result: "/Users/darwin/code/totalfinder/archive/dwarfs/Tabs.bundle.dSYM/Contents/Resources/DWARF/Tabs"
end

def Prism.resolve_symbol(symbol_address, module_name, crash_report)
  # module_name is lower-case last part of the bundle identifier eg. columnviewautowidth
  load_address = lookup_module_load_address(module_name, crash_report)
  version = lookup_module_version(module_name, crash_report)
  die "unable to lookup version for module #{module_name}" unless version

  dsym_path = dsym_path(module_name, version)
  die "unable to retrieve dsym_path for module #{module_name}@#{version}" unless dsym_path

  arch = 'x86_64' # TODO: this could be configurable in the future

  cmd = "atos -arch #{arch} -o \"#{dsym_path}\" -l #{load_address} #{symbol_address} 2>/dev/null"
  res = `#{cmd}`.strip
  die "failed: #{cmd}" unless $CHILD_STATUS.success?

  res
end

def Prism.retrieve_our_module_names(crash_report)
  list = []
  crash_report.scan /\+(com\.binaryage\..*?)(\s+)/ do |_|
    module_id = Regexp.last_match(1).strip
    list << module_id_to_name(module_id)
  end
  list.sort.uniq
end

def Prism.symbolize_crash_report(crash_report)
  # the crash report contains stack traces like this:
  #
  # 0   libobjc.A.dylib                 0x00007fff8e38244c _class_setInstancesHaveAssociatedObjects + 9
  # 1   libobjc.A.dylib                 0x00007fff8e3822fa _object_set_associative_reference + 443
  # 2   com.binaryage.totalfinder.tabs  0x000000010d5b9732 0x10d587000 + 206642
  # 3   com.binaryage.totalfinder.tabs  0x000000010d5b7542 0x10d587000 + 197954
  # ...

  our_modules = retrieve_our_module_names(crash_report)

  symbolized_crash_report = crash_report.gsub /^(\d+\s+)(.*?)(\s+)([xa-fA-F\d]+)(\s+)(.*)$/ do |_|
    hint = Regexp.last_match(6)
    symbol = Regexp.last_match(4)
    module_name = Regexp.last_match(2).downcase
    prefix = "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{Regexp.last_match(3)}" \
             "#{Regexp.last_match(4)}#{Regexp.last_match(5)}"
    resolved_symbol = hint

    module_name = module_id_to_name(module_name) if module_name.match?(/^com\.binaryage\./)

    resolved_symbol = resolve_symbol(symbol, module_name, crash_report) if our_modules.include? module_name

    "#{prefix}#{resolved_symbol}"
  end

  symbolized_crash_report
end

def Prism.symbolize_crash_report_from_sha(sha)
  crash_report = get_crash_report(sha)
  return unless crash_report
  symbolize_crash_report(crash_report)
end
