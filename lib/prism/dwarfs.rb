# frozen_string_literal: true

require 'fileutils'
require 'tempfile'

# http://stackoverflow.com/a/16598746/84283
def capture_stdout
  stdout = $stdout.dup
  Tempfile.open 'stdout-redirect' do |temp|
    $stdout.reopen temp.path, 'w+'
    yield if block_given?
    $stdout.reopen stdout
    temp.read
  end
end

def Prism.dwarfs_cache_dir
  File.join(cache_dir, 'dwarfs')
end

def Prism.work_dir
  File.join(@config[:workspace], 'tmp')
end

def Prism.ensure_dwarfs_cache_dir
  FileUtils.mkdir_p(dwarfs_cache_dir)
end

def Prism.dwarfs_path_in_cache(version)
  File.join(dwarfs_cache_dir, @config[:product].downcase + 'v' + version)
end

def Prism.dwarfs_exist?(version)
  dwarfs_path = dwarfs_path_in_cache(version)
  File.exist?(dwarfs_path)
end

# each product has own archive branch in the repo
# by convention PRODUCT-archive
# for example totalfinder-archive
# or totalterminal-archive
# https://github.com/binaryage/root/tree/totalfinder-archive
def Prism.product_branch
  @config[:product].downcase + '-archive'
end

# by convention product tags look like
#   totalfinder-archive-v1.7.7
#   totalfinder-archive-v1.7.8
#   totalfinder-archive-v1.7.9
#   totalfinder-archive-v1.7.10
#   totalfinder-archive-v1.7.11
#   totalfinder-archive-v1.7.12
#
#   or
#
#   totalterminal-archive-v1.4.11
#   totalterminal-archive-v1.5
#   totalterminal-archive-v1.5.4
#   totalterminal-archive-v1.6
#
def Prism.product_tag_prefix
  @config[:product].downcase + '-archive'
end

def Prism.exec(cmd)
  if @config[:verbose]
    puts "> #{cmd.yellow}"
    res = capture_stdout do
      system("#{cmd} 2>&1")
    end
  else
    res = `#{cmd} 2>&1`
  end
  unless $CHILD_STATUS.success?
    puts res
    die "failed: #{cmd}"
  end
  res
end

def Prism.update_archive
  ensure_dwarfs_cache_dir
  FileUtils.mkdir_p(work_dir)
  Dir.chdir(work_dir) do
    branch = product_branch
    repo = @config[:repo]
    unless File.exist?(branch)
      # see https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
      # don't do exec("git clone --recursive git@github.com:binaryage/totalfinder-archive.git")
      temp_folder = branch + '-test'
      FileUtils.rm_rf(temp_folder)
      cmd = "git clone -b \"#{branch}\" \"#{repo}\" \"#{temp_folder}\""
      puts "> #{cmd.yellow}"
      system(cmd) # this can take a long time, give user feedback
      die "failed: #{cmd}" unless $CHILD_STATUS.success?
      exec("mv \"#{temp_folder}\" \"#{branch}\"")
    end
    Dir.chdir(branch) do
      # reset & update
      exec('git clean -f -f -d') # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
      exec('git reset --hard HEAD^') # use previous commit to make working tree resilient to amends
      exec("git pull --tags --ff-only \"#{repo}\" #{branch}")
    end
  end
end

def Prism.download_dwarfs(version)
  update_archive
  Dir.chdir(work_dir) do
    branch = product_branch
    Dir.chdir(branch) do
      # find revision with our version
      expected_tag = "#{product_tag_prefix}-v#{version}"
      exec("git checkout \"#{expected_tag}\"")

      # copy dwarfs into cache (under version subfolder)
      dwarfs_path = dwarfs_path_in_cache(version)
      FileUtils.mkdir_p(dwarfs_path)
      FileUtils.cp_r(Dir.glob('dwarfs/*'), dwarfs_path)
    end
  end
end

def Prism.get_dwarfs(version)
  download_dwarfs(version) unless dwarfs_exist?(version)
  dwarfs_path_in_cache(version)
end

def Prism.clear_dwarfs_cache
  FileUtils.rm_rf(dwarfs_cache_dir)
end

def Prism.clear_work_dir
  FileUtils.rm_rf(work_dir)
end
