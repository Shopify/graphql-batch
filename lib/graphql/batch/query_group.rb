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
      if query.result.is_a?(QueryContainer)
        query_container = query.result
        query_container.query_listener = self
        @pending_queries << query_container
        register_queries(query_container)
      end
      if @pending_queries.empty?
        complete(@block.call)
      end
    end

    def register_queries(query_container)
      query_listener.register_queries(query_container)
    end
  end
end
