require 'fileutils'

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

def Prism.archive_pull_url()
  return "git@github.com:binaryage/totalfinder-archive.git" unless @config[:token]
  "https://#{@config[:token]}@github.com/binaryage/totalfinder-archive.git"
end

def Prism.exec(cmd)
  res = `#{cmd} 2>&1`
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
    unless File.exists?("totalfinder-archive")
      # see https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
      # don't do exec("git clone --recursive git@github.com:binaryage/totalfinder-archive.git")
      FileUtils.rm_rf("totalfinder-archive-test")
      FileUtils.mkdir("totalfinder-archive-test")
      Dir.chdir("totalfinder-archive-test") do
        exec("git init")
        exec("git pull #{archive_pull_url()}")
      end
      exec("mv totalfinder-archive-test totalfinder-archive")
    end
    Dir.chdir("totalfinder-archive") do
      # reset & update
      exec("git clean -f -f -d") # http://stackoverflow.com/questions/9314365/git-clean-is-not-removing-a-submodule-added-to-a-branch-when-switching-branches
      exec("git reset --hard HEAD^") # use previous commit to make working tree resilient to amends
      exec("git pull --ff-only \"#{archive_pull_url()}\"")
    end
  end
end

def Prism.download_dwarfs(version)
  update_archive()
  Dir.chdir(work_dir()) do
    Dir.chdir("totalfinder-archive") do
      # find revision with our version
      rev = exec("git log --grep=\"#{version}\" -n 1")
      commit = rev.split("\n")[0].split(" ")[1].strip

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
