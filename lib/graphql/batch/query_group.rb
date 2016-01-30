module GraphQL::Batch
  class QueryGroup < QueryContainer
    def initialize(queries)
      raise ArgumentError, "QueryGroup.new no longer takes a block, use #then instead" if block_given?
      super(self)
      @pending_queries = Set.new
      @results = []

      queries.each_with_index do |query, i|
        if query.is_a?(QueryContainer)
          @pending_queries.add(query)
        else
          @results[i] = query
        end
      end

      if @pending_queries.empty?
        complete(@results)
      else
        queries.each_with_index do |query, i|
          next unless query.is_a?(QueryContainer)
          query.then do |result|
            @results[i] = result
            @pending_queries.delete(query)
            if @pending_queries.empty?
              complete(@results)
            end
          end.rescue do |err|
            unless completed?
              @pending_queries = nil
              @results = nil
              complete(error: err)
            end
          end
        end
      end
    end

    def each_query
      return super if completed?
      @pending_queries.each do |query_container|
        query_container.each_query do |query|
          yield query
        end
      end
    end
  end
end
