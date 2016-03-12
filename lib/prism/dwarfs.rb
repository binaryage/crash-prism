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
  File.join(cache_dir(), "dwarfs")
end

def Prism.work_dir
  File.join(@config[:workspace], "tmp")
end

def Prism.ensure_existence_of_dwarfs_cache_dir
  FileUtils.mkdir_p(dwarfs_cache_dir())
end

def Prism.dwarfs_path_in_cache(version)
  File.join(dwarfs_cache_dir(), version)
end

def Prism.dwarfs_exist?(version)
  dwarfs_path = dwarfs_path_in_cache(version)
  File.exists?(dwarfs_path)
end

# each product has own archive branch in the repo
# by convention PRODUCT-archive
# for example totalfinder-archive 
# or totalterminal-archive
# https://github.com/binaryage/root/tree/totalfinder-archive
def Prism.product_branch()
  @config[:product].downcase + "-archive"
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
def Prism.product_tag_prefix()
  @config[:product].downcase + "-archive"
end

def Prism.exec(cmd)
  if (@config[:verbose]) then
    puts "> #{cmd.yellow}"
    res = capture_stdout do
      system("#{cmd} 2>&1")
    end
  else
    res = `#{cmd} 2>&1`
  end
  unless $?.success?
    puts res
    die "failed: #{cmd}"
  end
  res
end

def Prism.update_archive()
  ensure_existence_of_dwarfs_cache_dir()
  FileUtils.mkdir_p(work_dir())
  Dir.chdir(work_dir()) do
    branch = product_branch()
    repo = @config[:repo]
    unless File.exists?(branch)
      # see https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
      # don't do exec("git clone --recursive git@github.com:binaryage/totalfinder-archive.git")
      temp_folder = branch + "-test"
      FileUtils.rm_rf(temp_folder)
      cmd = "git clone -b \"#{branch}\" \"#{repo}\" \"#{temp_folder}\""
      puts "> #{cmd.yellow}"
      system(cmd) # this can take a long time, give user feedback
      unless $?.success?
        puts res
        die "failed: #{cmd}"
      end
      exec("mv \"#{temp_folder}\" \"#{branch}\"")
    end
    Dir.chdir(branch) do
      # reset & update
      exec("git clean -f -f -d") # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
      exec("git reset --hard HEAD^") # use previous commit to make working tree resilient to amends
      exec("git pull --ff-only \"#{repo}\"")
    end
  end
end

def Prism.download_dwarfs(version)
  update_archive()
  Dir.chdir(work_dir()) do
    branch = product_branch()
    Dir.chdir(branch) do
      # find revision with our version
      tag_matcher = "#{product_tag_prefix()}-v#{version}}"
      rev = exec("git log --grep=\"#{tag_matcher}\" -n 1 --format=oneline")
      die "unable to find archive commit with #{tag_matcher}" if rev.nil?
      commit = rev.split("\n")[0].split(" ")[0].strip

      die "failed to retrieve commit of dwarfs version #{version}" if commit.empty?

      # checkout our version
      exec("git checkout #{commit}")

      # copy dwarfs into cache (under version subfolder)
      dwarfs_path = dwarfs_path_in_cache(version)
      FileUtils.mkdir_p(dwarfs_path)
      FileUtils.cp_r(Dir.glob("dwarfs/*"), dwarfs_path)
    end
  end
end

def Prism.get_dwarfs(version)
  unless dwarfs_exist?(version)
    download_dwarfs(version)
  end
  dwarfs_path_in_cache(version)
end

def Prism.clear_dwarfs_cache()
  FileUtils.rm_rf(dwarfs_cache_dir())
end

def Prism.clear_work_dir()
  FileUtils.rm_rf(work_dir())
end
