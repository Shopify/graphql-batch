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

    autoload :ExecutionStrategy, 'graphql/batch/execution_strategy'
    autoload :MutationExecutionStrategy, 'graphql/batch/mutation_execution_strategy'
  end
end

require_relative "batch/version"
require_relative "batch/loader"
require_relative "batch/executor"
require_relative "batch/promise"
require_relative "batch/setup"
