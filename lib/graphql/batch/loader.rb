module GraphQL::Batch
  class Loader
    # Use new argument forwarding syntax if available as an optimization
    if RUBY_ENGINE && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7")
      class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        def self.for(...)
          current_executor.loader(loader_key_for(...)) { new(...) }
        end
      RUBY
    else
      def self.for(*group_args)
        current_executor.loader(loader_key_for(*group_args)) { new(*group_args) }
      end
    end

    def self.loader_key_for(*group_args, **group_kwargs)
      [self, group_kwargs, group_args]
    end

    def self.load(key)
      self.for.load(key)
    end

    def self.load_many(keys)
      self.for.load_many(keys)
    end

    class << self
      private

      def current_executor
        executor = Executor.current

        unless executor
          raise GraphQL::Batch::NoExecutorError, 'Cannot create loader without'\
            ' an Executor. Wrap the call to `for` with `GraphQL::Batch.batch`'\
            ' or use `GraphQL::Batch::SetupMultiplex` as a query instrumenter if'\
            ' using with `graphql-ruby`'
        end

        executor
      end
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
      promise = promise_for(key)
      # When a promise is fulfilled through this class, it will either:
      #   become fulfilled, if fulfilled with a literal value
      #   become pending with a new source if fulfilled with a promise
      # Either of these is acceptable, promise.rb will automatically re-wait
      # on the new source promise as needed.
      return true if promise.fulfilled?

      promise.pending? && promise.source != self
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
        next unless promise_for(key).pending?

        reject(key, err)
      end
    end

    def check_for_broken_promises(load_keys)
      load_keys.each do |key|
        promise = promise_for(key)
        # When a promise is fulfilled through this class, it will either:
        #   become not pending, if fulfilled with a literal value
        #   become pending with a new source if fulfilled with a promise
        # Either of these is acceptable, promise.rb will automatically re-wait
        # on the new source promise as needed.
        next unless promise.pending? && promise.source == self

        reject(key, ::Promise::BrokenError.new("#{self.class} didn't fulfill promise for key #{key.inspect}"))
      end
    end
  end
end
