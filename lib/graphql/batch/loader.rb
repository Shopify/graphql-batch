module GraphQL::Batch
  class Loader
    def self.for(*group_args)
      loader_key = [self].concat(group_args)
      Executor.current.loaders[loader_key] ||= new(*group_args).tap do |loader|
        loader.loader_key = loader_key
      end
    end

    def self.load(key)
      self.for.load(key)
    end

    def self.load_many(keys)
      self.for.load_many(keys)
    end

    attr_accessor :loader_key

    def load(key)
      loader = Executor.current.loaders[loader_key] ||= self
      if loader != self
        raise "load called on loader that wasn't registered with executor"
      end
      cache[cache_key(key)] ||= begin
        queue << key
        Promise.new
      end
    end

    def load_many(keys)
      Promise.all(keys.map { |key| load(key) })
    end

    def resolve #:nodoc:
      load_keys = queue
      return if load_keys.empty?
      @queue = nil
      perform(load_keys)
      check_for_broken_promises(load_keys)
    rescue => err
      each_pending_promise(load_keys) do |key, promise|
        promise.reject(err)
      end
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
        promise.reject(BrokenPromiseError.new("#{self.class} didn't fulfill promise for key #{key.inspect}"))
      end
    end
  end
end
