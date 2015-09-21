module GraphQL::Batch
  class QueryGroup < QueryContainer
    def initialize(queries, &block)
      @pending_queries = queries.dup
      @pending_queries.each do |query|
        query.query_listener = self
      end
      @block = block
      raise ArgumentError, "QueryGroup requires a block" unless block
    end

    def each_query
      @pending_queries.each do |query_container|
        query_container.each_query do |query|
          yield query
        end
      end
    end

    def query_completed(query)
      @pending_queries.delete(query)
      if @pending_queries.empty?
        result = @block.call
        @block = nil
        if result.is_a?(QueryContainer)
          result.query_listener = self
          @pending_queries << result
          register_queries(result)
        else
          complete(result)
        end
      end
    end
  end
end
