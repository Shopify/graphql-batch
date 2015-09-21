module GraphQL::Batch
  class Resolver
    attr_accessor :resolver_owner, :result

    def each_query
      raise NotImplementedError
    end

    def complete(result)
      if instance_variable_defined?(:@result)
        raise "Resolver was already completed"
      end
      @result = result
      resolver_owner.child_completed(self)
    end
  end
end
