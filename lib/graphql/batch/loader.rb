module GraphQL::Batch
  class Loader
    class NoExecutorError < StandardError; end

    def self.for(*group_args)
      loader_key = loader_key_for(*group_args)
      executor = Executor.current

      unless executor
        raise NoExecutorError, "Cannot create loader without an Executor."\
          " Wrap the call to `for` with `GraphQL::Batch.batch` or use"\
          " `GraphQL::Batch::Setup` as a query instrumenter if using with `graphql-ruby`"
      end

      executor.loaders[loader_key] ||= new(*group_args).tap do |loader|
        loader.loader_key = loader_key
        loader.executor = executor
      end
    end

    def self.loader_key_for(*group_args)
      [self].concat(group_args)
    end

    def self.load(key)
      self.for.load(key)
    end

    def self.load_many(keys)
      self.for.load_many(keys)
    end

    attr_accessor :loader_key, :executor

    def load(key)
      cache[cache_key(key)] ||= begin
        queue << key
        Promise.new.tap { |promise| promise.source = self }
      end
    end

    def load_many(keys)
      ::Promise.all(keys.map { |key| load(key) })
    end

    def resolve #:nodoc:
      return if resolved?
      load_keys = queue
      @queue = nil
      perform(load_keys)
      check_for_broken_promises(load_keys)
    rescue => err
      each_pending_promise(load_keys) do |key, promise|
        promise.reject(err)
      end
    end

    # For Promise#sync
    def wait #:nodoc:
      if executor
        executor.loaders.delete(loader_key)
        executor.resolve(self)
      else
        resolve
      end
    end

    def resolved?
      @queue.nil? || @queue.empty?
    end

    protected

    # Fulfill the key with provided value, for use in #perform
    def fulfill(key, value)
      promise_for(key).fulfill(value)
    end

    # Returns true when the key has already been fulfilled, otherwise returns false
    def fulfilled?(key)
      promise_for(key).fulfilled?
    end

    # Must override to load the keys and call #fulfill for each key
    def perform(keys)
      raise NotImplementedError
    end

    # Override to use a different key for the cache than the load key
    def cache_key(load_key)
      load_key
    end

    private

    def cache
      @cache ||= {}
    end

    def queue
      @queue ||= []
    end

    def promise_for(load_key)
      cache.fetch(cache_key(load_key))
    end

    def each_pending_promise(load_keys)
      load_keys.each do |key|
        promise = promise_for(key)
        if promise.pending?
          yield key, promise
        end
      end
    end

    def check_for_broken_promises(load_keys)
      each_pending_promise(load_keys) do |key, promise|
        promise.reject(::Promise::BrokenError.new("#{self.class} didn't fulfill promise for key #{key.inspect}"))
      end
    end
  end
end
