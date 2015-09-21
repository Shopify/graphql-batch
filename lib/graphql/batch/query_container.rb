module GraphQL::Batch
  class QueryContainer
    attr_accessor :query_listener, :result

    def each_query
      raise NotImplementedError
    end

    def complete(result)
      if result.is_a?(QueryContainer)
        result.query_listener = self
        register_queries(result)
      else
        if instance_variable_defined?(:@result)
          raise "Query was already completed"
        end
        @result = result
        query_listener.query_completed(self)
      end
    end

    def query_completed(query)
      complete(query.result)
    end

    def register_queries(query_container)
      query_listener.register_queries(query_container)
    end
  end
end
