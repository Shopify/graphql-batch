require "graphql"
if Gem::Version.new(GraphQL::VERSION) < Gem::Version.new("1.3")
  warn "graphql gem versions less than 1.3 are deprecated for use with graphql-batch, upgrade so lazy_resolve can be used"
end
require "promise.rb"

module GraphQL
  module Batch
    BrokenPromiseError = ::Promise::BrokenError
    class NestedError < StandardError; end

    def self.batch
      # TODO: Should this be allowed now?
      raise NestedError if GraphQL::Batch::Executor.current
      begin
        GraphQL::Batch::Executor.current = GraphQL::Batch::Executor.new
        Promise.sync(yield)
      ensure
        GraphQL::Batch::Executor.current = nil
      end
    end

    def self.use(schema_defn)
      schema_defn.instrument(:query, GraphQL::Batch::Setup)
      schema_defn.lazy_resolve(::Promise, :sync)
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
