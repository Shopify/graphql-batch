module GraphQL::Batch
  class Query < QueryContainer
    def initialize
      raise ArgumentError, "QueryGroup.new no longer takes a block, use #then instead" if block_given?
      super(self)
    end

    def each_query
      return super if @query != self
      yield self
    end

    # batched queries with the same key are merged together
    def group_key
      self.class.name
    end

    # execute queries, with the same group_key, as a batch
    def self.execute(queries)
      raise NotImplementedError
    end
  end
end
