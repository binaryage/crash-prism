# frozen_string_literal: true

require 'fileutils'

def Prism.cache_dir
  File.join(@config[:workspace], 'cache')
end

def Prism.gist_cache_dir
  File.join(cache_dir, 'gists')
end

def Prism.ensure_existence_of_gist_cache_dir
  FileUtils.mkdir_p(gist_cache_dir)
end

def Prism.gist_path_in_cache(sha)
  File.join(gist_cache_dir, "#{sha}.crash")
end

def Prism.get_gist_from_cache(sha)
  gist_path = gist_path_in_cache(sha)
  return unless File.exist? gist_path
  File.read(gist_path)
end

def Prism.store_gist_to_cache(sha, content)
  ensure_existence_of_gist_cache_dir
  File.open(gist_path_in_cache(sha), 'w') do |f|
    f.write(content)
  end
end

def Prism.clear_gist_cache
  FileUtils.rm_rf(gist_cache_dir)
end
