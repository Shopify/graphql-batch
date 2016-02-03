module GraphQL::Batch
  class QueryCallback < QueryContainer
    def initialize(query, &block)
      super(query)
      @block = block
    end

    def call(result, error)
      begin
        complete(@block.call(result, error))
      rescue => block_error
        complete(error: block_error)
      end
    end
  end
end
