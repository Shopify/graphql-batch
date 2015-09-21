module GraphQL::Batch
  class QueryContainer
    attr_accessor :query_listener, :result

    def each_query
      raise NotImplementedError
    end

    def complete(result)
      if instance_variable_defined?(:@result)
        raise "Query was already completed"
      end
      @result = result
      query_listener.query_completed(self)
    end
  end
end
