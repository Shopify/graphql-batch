module GraphQL::Batch
  class Executor
    THREAD_KEY = :"#{name}.batched_queries"
    private_constant :THREAD_KEY

    def self.current
      Thread.current[THREAD_KEY] ||= new
    end

    attr_reader :loaders

    def initialize
      @loaders = {}
    end

    def shift
      @loaders.shift.last
    end

    def tick
      shift.resolve
    end

    def wait(promise)
      tick while promise.pending?
    end

    def clear
      loaders.clear
    end
  end
end
