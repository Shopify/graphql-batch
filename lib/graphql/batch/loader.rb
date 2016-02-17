module GraphQL::Batch
  class Loader
    def self.for(*group_args)
      Executor.current.loaders[group_args] ||= new(*group_args)
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

    def fulfill(key, value)
      promises_by_key[key].fulfill(value)
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

    def check_for_broken_promises
      promises_by_key.each do |key, promise|
        if promise.pending?
          promise.reject(BrokenPromiseError.new("#{self.class} didn't fulfill promise for key #{key.inspect}"))
        end
      end
    end
  end
end
