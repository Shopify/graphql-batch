module GraphQL::Batch
  class Setup
    class << self
      def start_batching
        raise NestedError if GraphQL::Batch::Executor.current
        GraphQL::Batch::Executor.current = GraphQL::Batch::Executor.new
      end

      def end_batching
        GraphQL::Batch::Executor.current = nil
      end

      def instrument_field(schema, type, field)
        return field unless type == schema.mutation
        old_resolve_proc = field.resolve_proc
        field.redefine do
          resolve ->(obj, args, ctx) {
            GraphQL::Batch::Executor.current.clear
            begin
              ::Promise.sync(old_resolve_proc.call(obj, args, ctx))
            ensure
              GraphQL::Batch::Executor.current.clear
            end
          }
        end
      end

      def before_query(query)
        warn "Deprecated graphql-batch setup `instrument(:query, GraphQL::Batch::Setup)`, replace with `use GraphQL::Batch`"
        start_batching
      end

      def after_query(query)
        end_batching
      end
    end

    def initialize(schema)
      @schema = schema
    end

    def before_query(query)
      Setup.start_batching
    end

    def after_query(query)
      Setup.end_batching
    end

    def instrument(type, field)
      Setup.instrument_field(@schema, type, field)
    end
  end
end
