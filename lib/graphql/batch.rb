# frozen_string_literal: true

require 'graphql'
require 'promise.rb'

module GraphQL
  module Batch
    BrokenPromiseError = ::Promise::BrokenError
    class NoExecutorError < StandardError; end

    def self.batch(executor_class: GraphQL::Batch::Executor)
      GraphQL::Batch::Executor.start_batch(executor_class)
      ::Promise.sync(yield)
    ensure
      GraphQL::Batch::Executor.end_batch
    end

    def self.use(schema_defn, executor_class: GraphQL::Batch::Executor)
      # Support 1.10+ which passes the class instead of the definition proxy
      schema = schema_defn.is_a?(Class) ? schema_defn : schema_defn.target
      current_gem_version = Gem::Version.new(GraphQL::VERSION)
      if current_gem_version >= Gem::Version.new('1.6.0')
        instrumentation = GraphQL::Batch::SetupMultiplex.new(schema, executor_class: executor_class)
        schema_defn.instrument(:multiplex, instrumentation)
        if schema.mutation
          if current_gem_version >= Gem::Version.new('1.9.0.pre3') &&
             (schema.mutation.is_a?(Class) || schema.mutation.metadata[:type_class])
            require_relative 'batch/mutation_field_extension'
            schema.mutation.fields.each do |_name, f|
              field = f.respond_to?(:type_class) ? f.type_class : f.metadata[:type_class]
              field.extension(GraphQL::Batch::MutationFieldExtension)
            end
          else
            schema_defn.instrument(:field, instrumentation)
          end
        end
      else
        instrumentation = GraphQL::Batch::Setup.new(schema, executor_class: executor_class)
        schema_defn.instrument(:query, instrumentation)
        schema_defn.instrument(:field, instrumentation)
      end
      schema_defn.lazy_resolve(::Promise, :sync)
    end
  end
end

require_relative 'batch/version'
require_relative 'batch/loader'
require_relative 'batch/executor'
require_relative 'batch/setup'
require_relative 'batch/setup_multiplex'
