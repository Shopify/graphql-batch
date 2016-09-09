module GraphQL::Batch
  class Loader
    def self.for(*group_args)
      loader_key = [self].concat(group_args)
      Executor.current.loaders[loader_key] ||= new(*group_args)
    end

    def self.load(key)
      self.for.load(key)
    end

    def self.load_many(keys)
      self.for.load_many(keys)
    end

    def promises_by_key
      @promises_by_key ||= {}
    end

    def keys
      promises_by_key.keys
    end

    def load(key)
      promises_by_key[key] ||= Promise.new
    end

    def load_many(keys)
      Promise.all(keys.map { |key| load(key) })
    end

    def fulfill(key, value)
      expect_promise_key!(key)
      promises_by_key[key].fulfill(value)
    end

    def fulfilled?(key)
      expect_promise_key!(key)
      promises_by_key[key].fulfilled?
    end

    # batch load keys and fulfill promises
    def perform(keys)
      raise NotImplementedError
    end

    def resolve
      perform(keys)
      check_for_broken_promises
    rescue => err
      promises_by_key.each do |key, promise|
        promise.reject(err)
      end
    end

    private

    def expect_promise_key!(key)
      raise "No promise with key #{key} to fulfill" unless promises_by_key.key?(key)
    end

    def check_for_broken_promises
      promises_by_key.each do |key, promise|
        if promise.pending?
          promise.reject(BrokenPromiseError.new("#{self.class} didn't fulfill promise for key #{key.inspect}"))
        end
      end
    end
  end
end
