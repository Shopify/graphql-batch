module GraphQL::Batch
  class MutationExecutionStrategy < GraphQL::Query::SerialExecution
    class FieldResolution < GraphQL::Query::SerialExecution::FieldResolution
      def get_finished_value(raw_value)
        raw_value = GraphQL::Batch::Promise.resolve(raw_value).sync

        begin
          result = super(raw_value)
          GraphQL::Batch::Executor.current.wait_all
          result
        end
      end
    end
  end
end
