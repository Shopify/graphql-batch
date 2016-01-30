require "graphql"

module GraphQL
  module Batch
    module_function

    def execute(container)
      unless container.is_a?(QueryContainer)
        return container
      end
      if container.completed?
        raise container.error if container.error
        return container.result
      end

      batched_queries = Hash.new{ |hash, key| hash[key] = [] }
      register_queries = lambda do |query_container|
        query_container.each_query do |query|
          batched_queries[query.group_key] << query
        end
      end
      register_queries.call(container)

      until batched_queries.empty?
        queries = batched_queries.shift.last
        begin
          queries.first.class.execute(queries)
        rescue => err
          queries.each do |query|
            query.complete(error: err) unless query.completed?
          end
        end
        queries.each do |query|
          register_queries.call(query)
        end
      end
      raise container.error if container.error
      container.result
    end
  end
end

require_relative "batch/version"
require_relative "batch/query_container"
require_relative "batch/query_callback"
require_relative "batch/query"
require_relative "batch/query_group"
require_relative "batch/execution_strategy"
