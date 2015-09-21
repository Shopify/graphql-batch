module GraphQL::Batch
  class QueryGroup < Resolver
    def initialize(queries, &block)
      @pending_queries = Array(queries)
      @pending_queries.each do |query|
        query.resolver_owner = self
      end
      @block = block
      raise ArgumentError, "QueryGroup requires a block" unless block
    end

    def each_query
      @pending_queries.each do |query|
        yield query
      end
    end

    def child_completed(query)
      if @pending_queries.delete(query) && @pending_queries.empty?
        complete(@block.call)
      end
    end
  end
end
