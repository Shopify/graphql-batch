$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'graphql/batch'

require_relative 'support/loaders'
require_relative 'support/schema'
require_relative 'support/db'

require 'minitest/autorun'
