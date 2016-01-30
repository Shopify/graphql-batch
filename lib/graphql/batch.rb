require "graphql"
require "promise.rb"

module GraphQL
  module Batch
  end
end

require_relative "batch/version"
require_relative "batch/loader"
require_relative "batch/executor"
require_relative "batch/promise"
require_relative "batch/execution_strategy"
