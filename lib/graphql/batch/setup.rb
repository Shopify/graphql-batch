# frozen_string_literal: true

module GraphQL::Batch
  class Setup
    class << self
      def start_batching(executor_class)
        GraphQL::Batch::Executor.start_batch(executor_class)
      end

      def end_batching
        GraphQL::Batch::Executor.end_batch
      end

      def instrument_field(schema, type, field)
        return field unless type == schema.mutation

        old_resolve_proc = field.resolve_proc
        field.redefine do
          resolve lambda { |obj, args, ctx|
            GraphQL::Batch::Executor.current.clear
            begin
              ::Promise.sync(old_resolve_proc.call(obj, args, ctx))
            ensure
              GraphQL::Batch::Executor.current.clear
            end
          }
        end
      end
    end

    def initialize(schema, executor_class:)
      @schema = schema
      @executor_class = executor_class
    end

    def before_query(_query)
      Setup.start_batching(@executor_class)
    end

    def after_query(_query)
      Setup.end_batching
    end

    def instrument(type, field)
      Setup.instrument_field(@schema, type, field)
    end
  end
end
