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
  "#{@config[:token]}@github.com:binaryage/totalfinder-archive.git"
end

def Prism.download_dwarfs(version)
  ensure_existence_of_dwarfs_cache_dir()
  FileUtils.mkdir_p(work_dir())
  Dir.chdir(work_dir()) do
    unless File.exists?("totalfinder-archive")
      # see https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
      # don't do system("git clone --recursive git@github.com:binaryage/totalfinder-archive.git")
      FileUtils.mkdir("totalfinder-archive")
      Dir.chdir("totalfinder-archive") do
        system("git init")
        system("git pull #{archive_pull_url()}")
      end
    end
    Dir.chdir("totalfinder-archive") do
      # reset & update
      system("git checkout master")
      system("git reset --hard HEAD")
      system("git pull #{archive_pull_url()}")

      # find revision with our version
      rev = `git log --grep="#{version}" -n 1`
      commit = rev.split("\n")[0].split(" ")[1].strip

      die "failed to retrieve commit of dwarfs version #{version}" if commit.empty?

      # checkout our version
      system("git checkout #{commit}")

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
