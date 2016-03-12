module Prism
  VERSION = "0.3.0"
  @config = {
    :workspace => "/tmp/crash-prism",
    :repo => "github.com:binaryage/root.git", # you might need to specify token: https://
    :product => "TotalFinder"
  }
  class << self; attr_accessor :config; end # an ugly way how to expose Prism.config to outside world
end

require_relative 'prism/cache.rb'
require_relative 'prism/dwarfs.rb'
require_relative 'prism/core.rb'