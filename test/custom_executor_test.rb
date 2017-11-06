require_relative 'test_helper'

class GraphQL::Batch::CustomExecutorTest < Minitest::Test
  class MyCustomExecutor < GraphQL::Batch::Executor
    @@call_count = 0

    def self.call_count
      @@call_count
    end

    def around_promise_callbacks
      @@call_count += 1

      super
    end
  end

  def test_custom_executor_class
    schema = GraphQL::Schema.define do
      query ::QueryType
      mutation ::MutationType

      use GraphQL::Batch, executor_class: MyCustomExecutor
    end

    query_string = '{ product(id: "1") { id } }'
    schema.execute(query_string)

    assert MyCustomExecutor.call_count > 0
  end
end
