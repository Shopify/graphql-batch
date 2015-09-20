module GraphQL::Batch
  class Query
    attr_accessor :resolver
    attr_reader :result

    # batched queries with the same key are merged together
    def group_key
      self.class.name
    end

    def complete(result)
      @result = result
      resolver.query_completed(self)
    end

    # execute queries, with the same group_key, as a batch
    def self.execute(queries)
      raise NotImplementedError
    end
  end
end
