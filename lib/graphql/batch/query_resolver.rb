module GraphQL::Batch
  class QueryResolver < Resolver
    def initialize(query)
      query.resolver = self
      @query = query
    end

    def each_query
      yield @query
    end

    def query_completed(query)
      resolve(query.result)
    end
  end
end
