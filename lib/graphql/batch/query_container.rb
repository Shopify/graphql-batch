module GraphQL::Batch
  class QueryContainer
    attr_accessor :query
    attr_accessor :result, :error
    attr_accessor :callback

    def initialize(query)
      @query = query
    end

    def each_query
      @query.each_query { |query| yield query } if @query
    end

    def then(&block)
      raise ArgumentError, "Required block not given" unless block
      on_complete do |result, error|
        raise error if error
        block.call(result)
      end
    end

    def rescue(error_class=StandardError, &block)
      raise ArgumentError, "Required block not given" unless block
      on_complete do |result, error|
        if error
          raise error unless error.is_a?(error_class)
          block.call(error)
        else
          result
        end
      end
    end

    def ensure(&block)
      raise ArgumentError, "Required block not given" unless block
      on_complete do |result, error|
        block.call(result, error)
        raise error if error
        result
      end
    end

    def complete(result = nil, error: nil)
      if result.is_a?(QueryContainer)
        @query = result
        @query.on_complete do |nested_result, nested_error|
          complete(nested_result, error: nested_error)
        end
        return
      end

      if completed?
        raise "Query was already completed"
      end
      @query = nil
      @completed = true
      @result = result
      @error = error
      call_callback if @callback
    end

    def completed?
      @completed
    end

    def execute
      GraphQL::Batch.execute(self)
    end

    protected

    def on_complete(&block)
      callback = QueryCallback.new(self, &block)
      @callback = callback
      call_callback if completed?
      callback
    end

    private

    def call_callback
      @callback.call(@result, @error)
      @query = @callback.query
      @callback = nil
    end
  end
end
