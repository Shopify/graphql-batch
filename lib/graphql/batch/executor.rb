module GraphQL::Batch
  class Executor
    THREAD_KEY = :"#{name}.batched_queries"
    private_constant :THREAD_KEY

    def self.current
      Thread.current[THREAD_KEY]
    end

    def self.current=(executor)
      Thread.current[THREAD_KEY] = executor
    end

    attr_reader :loaders

    # Set to true when performing a batch query, otherwise, it is false.
    #
    # Can be used to detect unbatched queries in an ActiveSupport::Notifications.subscribe block.
    attr_reader :loading

    def initialize
      @loaders = {}
      @loading = false
    end

    def resolve(loader)
      with_loading(true) { loader.resolve }
    end

    def shift
      @loaders.shift.last
    end

    def tick
      resolve(shift)
    end

    def wait_all
      tick until loaders.empty?
    end

    def clear
      loaders.clear
    end

    def defer
      # Since we aren't actually deferring callbacks, we need to set #loading to false so that any queries
      # that happen in the callback aren't interpreted as being performed in GraphQL::Batch::Loader#perform
      with_loading(false) { yield }
    end

    private

    def with_loading(loading)
      was_loading = @loading
      begin
        @loading = loading
        yield
      ensure
        @loading = was_loading
      end
    end
  end
end
