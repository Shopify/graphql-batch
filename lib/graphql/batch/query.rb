module GraphQL::Batch
  class Query < QueryContainer
    def initialize(&block)
      @block = block
    end

    # batched queries with the same key are merged together
    def group_key
      self.class.name
    end

    def each_query
      yield self
    end

    def complete(result)
      if @block
        result = @block.call(result)
        @block = nil
      end
      super(result)
    end

    # execute queries, with the same group_key, as a batch
    def self.execute(queries)
      raise NotImplementedError
    end
  end
end
