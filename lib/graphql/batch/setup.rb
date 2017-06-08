module GraphQL::Batch
  module Setup
    extend self
    BATCH_COUNT = "#{name}.executor_count"

    def before_query(query)
      GraphQL::Batch::Executor.current = GraphQL::Batch::Executor.new if (self.batch_count += 1) == 1
    end

    def after_query(query)
      GraphQL::Batch::Executor.current = nil if (self.batch_count -= 1) == 0
    end

    def batch_count
      Thread.current[BATCH_COUNT] || 0
    end

    def batch_count=(value)
      Thread.current[BATCH_COUNT] = (value > 0 ? value : nil)
    end
  end
end
