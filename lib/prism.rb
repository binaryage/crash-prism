# frozen_string_literal: true

module Prism
  VERSION = '0.4.0'
  @config = {
    workspace: '/tmp/crash-prism',
    repo: 'git@github.com:binaryage/root.git', # you might need to specify token: https://
    product: 'TotalFinder'
  }
  class << self
    attr_accessor :config
    # an ugly way how to expose Prism.config to outside world
  end
end

require_relative 'prism/cache.rb'
require_relative 'prism/dwarfs.rb'
require_relative 'prism/core.rb'
