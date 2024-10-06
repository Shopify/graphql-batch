module GraphQL::Batch
  class Executor
    THREAD_KEY = :"#{name}.batched_queries"
    private_constant :THREAD_KEY

    class << self
      def current
        Thread.current[THREAD_KEY]
      end

      def current=(executor)
        Thread.current[THREAD_KEY] = executor
      end

      def start_batch(executor_class)
        executor = Thread.current[THREAD_KEY] ||= executor_class.new
        executor.increment_level
      end

      def end_batch
        executor = current
        unless executor
          raise NoExecutorError, 'Cannot end a batch without an Executor.'
        end
        return unless executor.decrement_level < 1
        self.current = nil
      end
    end

    # Set to true when performing a batch query, otherwise, it is false.
    #
    # Can be used to detect unbatched queries in an ActiveSupport::Notifications.subscribe block.
    attr_reader :loading

    def initialize
      @loaders = {}
      @loading = false
      @nesting_level = 0
    end

    def loader(key)
      @loaders[key] ||= yield.tap do |loader|
        loader.executor = self
        loader.loader_key = key
      end
    end

    def resolve(loader)
      was_loading = @loading
      @loading = true
      loader.resolve
    ensure
      @loading = was_loading
    end

    def defer(_loader)
      while (non_deferred_loader = @loaders.find { |_, loader| !loader.deferred })
        resolve(non_deferred_loader)
      end
    end

    def on_wait
      # FIXME: Better name?
      @loaders.each do |_, loader|
        loader.on_any_wait
      end
    end

    def tick
      resolve(@loaders.shift.last)
    end

    def wait_all
      tick until @loaders.empty?
    end

    def clear
      @loaders.clear
    end

    def increment_level
      @nesting_level += 1
    end

    def decrement_level
      @nesting_level -= 1
    end

    def around_promise_callbacks
      # We need to set #loading to false so that any queries that happen in the promise
      # callback aren't interpreted as being performed in GraphQL::Batch::Loader#perform
      was_loading = @loading
      @loading = false
      yield
    ensure
      @loading = was_loading
    end
  end
end
