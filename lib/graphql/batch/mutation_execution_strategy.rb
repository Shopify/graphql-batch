require_relative "execution_strategy"

module GraphQL::Batch
  class MutationExecutionStrategy < GraphQL::Batch::ExecutionStrategy
    attr_accessor :enable_batching

    class FieldResolution < GraphQL::Batch::ExecutionStrategy::FieldResolution
      def get_finished_value(raw_value)
        strategy = execution_context.strategy
        return super if strategy.enable_batching

        begin
          strategy.enable_batching = true
          strategy.deep_sync(Promise.sync(super))
        ensure
          strategy.enable_batching = false
        end
      end
    end
  end
end
