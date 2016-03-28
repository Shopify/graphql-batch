module GraphQL::Batch
  class MutationExecutionStrategy < GraphQL::Query::SerialExecution
    class FieldResolution < GraphQL::Query::SerialExecution::FieldResolution
      def get_finished_value(raw_value)
        raw_value = GraphQL::Batch::Promise.resolve(raw_value).sync

        context = execution_context.query.context
        old_execution_strategy = context.execution_strategy
        begin
          context.execution_strategy = GraphQL::Batch::ExecutionStrategy.new
          result = super(raw_value)
          GraphQL::Batch::Executor.current.wait_all
          result
        ensure
          context.execution_strategy = old_execution_strategy
        end
      end
    end
  end
end
