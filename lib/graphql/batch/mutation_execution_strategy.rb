module GraphQL::Batch
  class MutationExecutionStrategy < GraphQL::Batch::ExecutionStrategy
    class FieldResolution < GraphQL::Batch::ExecutionStrategy::FieldResolution
      def get_finished_value(raw_value)
        return super if execution_context.strategy.disable_batching

        raw_value = Promise.sync(raw_value)

        execution_context.strategy.disable_batching = true
        begin
          result = super(raw_value)
          GraphQL::Batch::Executor.current.wait_all
          result
        ensure
          execution_context.strategy.disable_batching = false
        end
      end
    end
  end
end
