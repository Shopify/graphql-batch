require 'set'

module GraphQL::Batch
  class QueriesResolver < Resolver
    attr_reader :pending_queries

    def initialize(queries:, resolve:)
      queries.each do |query|
        query.resolver = self
      end
      @pending_queries = Set.new(queries)
      @resolve = resolve
    end

    def each_query
      @pending_queries.each do |query|
        yield query
      end
    end

    def query_completed(query)
      if @pending_queries.delete?(query) && @pending_queries.empty?
        resolve(@resolve.call)
      end
    end
  end
end
