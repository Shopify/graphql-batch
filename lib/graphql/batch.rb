require "graphql"
require "promise.rb"

module GraphQL
  module Batch
    BrokenPromiseError = ::Promise::BrokenError
    class NestedError < StandardError; end

    def self.batch
      raise NestedError if GraphQL::Batch::Executor.current
      begin
        GraphQL::Batch::Executor.current = GraphQL::Batch::Executor.new
        Promise.sync(yield)
      ensure
        GraphQL::Batch::Executor.current = nil
      end
    end
  end
end

require_relative "batch/version"
require_relative "batch/loader"
require_relative "batch/executor"
require_relative "batch/promise"
require_relative "batch/setup"

# Allow custom execution strategies to be removed upstream
if defined?(GraphQL::Query::SerialExecution)
  require_relative "batch/execution_strategy"
  require_relative "batch/mutation_execution_strategy"
end
