require "graphql"
require "promise.rb"

module GraphQL
  module Batch
    BrokenPromiseError = Class.new(StandardError)
  end
end

require_relative "batch/version"
require_relative "batch/loader"
require_relative "batch/executor"
require_relative "batch/promise"
