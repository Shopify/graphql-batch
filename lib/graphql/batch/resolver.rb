module GraphQL::Batch
  class Resolver
    attr_accessor :result_hash, :field_resolution

    def each_query
      raise NotImplementedError
    end

    def query_completed(query)
      raise NotImplementedError
    end

    def result_key
      ast_node = @field_resolution.ast_node
      ast_node.alias || ast_node.name
    end

    def resolve(raw_value)
      @result_hash[result_key] = @field_resolution.get_finished_value(raw_value)
    end
  end
end
