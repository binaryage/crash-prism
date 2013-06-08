module Prism
  VERSION = "0.1.0"
  @config = {
    :workspace => "/tmp/crash-prism",
    :token => "git"
  }
  class << self; attr_accessor :config; end # an ugly way how to expose Prism.config to outside world
end

require_relative 'prism/cache.rb'
require_relative 'prism/dwarfs.rb'
require_relative 'prism/core.rb'
