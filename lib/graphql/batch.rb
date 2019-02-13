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

    def self.use(schema_defn, executor_class: GraphQL::Batch::Executor)
      schema = schema_defn.target
      if Gem::Version.new(GraphQL::VERSION) >= Gem::Version.new('1.9.0.pre3')
        require_relative "batch/mutation_field_extension"
        if schema.mutation
          schema.mutation.fields.each do |name, f|
            field = f.metadata[:type_class]
            field.extension(GraphQL::Batch::MutationFieldExtension)
          end
        end
        instrumentation = GraphQL::Batch::SetupMultiplex.new(schema, executor_class: executor_class)
        schema_defn.instrument(:multiplex, instrumentation)
      elsif GraphQL::VERSION >= "1.6.0"
        instrumentation = GraphQL::Batch::SetupMultiplex.new(schema, executor_class: executor_class)
        schema_defn.instrument(:multiplex, instrumentation)
        schema_defn.instrument(:field, instrumentation)
      else
        instrumentation = GraphQL::Batch::Setup.new(schema, executor_class: executor_class)
        schema_defn.instrument(:query, instrumentation)
        schema_defn.instrument(:field, instrumentation)
      end
      schema_defn.lazy_resolve(::Promise, :sync)
    end
  end
end

require_relative "batch/version"
require_relative "batch/loader"
require_relative "batch/executor"
require_relative "batch/setup"
require_relative "batch/setup_multiplex"
