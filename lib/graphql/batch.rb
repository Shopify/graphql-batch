require "graphql"
require "promise.rb"

module GraphQL
  module Batch
    BrokenPromiseError = ::Promise::BrokenError
    class NoExecutorError < StandardError; end

    def self.batch(executor_class: GraphQL::Batch::Executor)
      begin
        GraphQL::Batch::Executor.start_batch(executor_class)
        ::Promise.sync(yield)
      ensure
        GraphQL::Batch::Executor.end_batch
      end
    end

    def self.use(schema, executor_class: GraphQL::Batch::Executor)
      instrumentation = GraphQL::Batch::SetupMultiplex.new(schema, executor_class: executor_class)
      schema.instrument(:multiplex, instrumentation)
      if schema.mutation
        if schema.mutation.is_a?(Class) || schema.mutation.metadata[:type_class]
          require_relative "batch/mutation_field_extension"
          schema.mutation.fields.each do |name, f|
            field = f.respond_to?(:type_class) ? f.type_class : f.metadata[:type_class]
            field.extension(GraphQL::Batch::MutationFieldExtension)
          end
        else
          schema.instrument(:field, instrumentation)
        end
      end
      schema.lazy_resolve(::Promise, :sync)
    end
  end
end

require_relative "batch/version"
require_relative "batch/loader"
require_relative "batch/executor"
require_relative "batch/setup"
require_relative "batch/setup_multiplex"
