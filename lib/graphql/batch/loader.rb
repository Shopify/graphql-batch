module GraphQL::Batch
  class Loader
    class NoExecutorError < StandardError; end
    deprecate_constant :NoExecutorError

    def self.for(*group_args)
      loader_key = loader_key_for(*group_args)
      executor = Executor.current

      unless executor
        raise GraphQL::Batch::NoExecutorError, 'Cannot create loader without'\
          ' an Executor. Wrap the call to `for` with `GraphQL::Batch.batch`'\
          ' or use `GraphQL::Batch::Setup` as a query instrumenter if'\
          ' using with `graphql-ruby`'
      end

      executor.loader(loader_key) { new(*group_args) }
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
        ::Promise.new.tap { |promise| promise.source = self }
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
      reject_pending_promises(load_keys, err)
    end

    # For Promise#sync
    def wait #:nodoc:
      if executor
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
      finish_resolve(key) do |promise|
        promise.fulfill(value)
      end
    end

    def reject(key, reason)
      finish_resolve(key) do |promise|
        promise.reject(reason)
      end
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

    def finish_resolve(key)
      promise = promise_for(key)
      return yield(promise) unless executor
      executor.around_promise_callbacks do
        yield promise
      end
    end

    def cache
      @cache ||= {}
    end

    def queue
      @queue ||= []
    end

    def promise_for(load_key)
      cache.fetch(cache_key(load_key))
    end

    def reject_pending_promises(load_keys, err)
      load_keys.each do |key|
        # promise.rb ignores reject if promise isn't pending
        reject(key, err)
      end
    end

    def check_for_broken_promises(load_keys)
      load_keys.each do |key|
        reject(key, ::Promise::BrokenError.new("#{self.class} didn't fulfill promise for key #{key.inspect}"))
      end
    end
  end
end
