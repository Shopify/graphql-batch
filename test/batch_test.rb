require_relative 'test_helper'

class GraphQL::BatchTest < Minitest::Test
  def test_batch
    product = GraphQL::Batch.batch do
      RecordLoader.for(Product).load(1)
    end
    assert_equal 'Shirt', product.title
  end

  class MyCustomExecutor < GraphQL::Batch::Executor
    @call_count = 0

    class << self
      attr_accessor :call_count
    end

    def around_promise_callbacks
      self.class.call_count += 1

      super
    end
  end

  def test_batch_accepts_custom_executor
    product = GraphQL::Batch.batch(executor_class: MyCustomExecutor) do
      RecordLoader.for(Product).load(1)
    end

    assert_equal 'Shirt', product.title
    assert MyCustomExecutor.call_count > 0
  end

  def test_nested_batch
    promise1 = nil
    promise2 = nil

    product = GraphQL::Batch.batch do
      promise1 = RecordLoader.for(Product).load(1)
      GraphQL::Batch.batch do
        promise2 = RecordLoader.for(Product).load(1)
      end
      promise1
    end

    assert_equal 'Shirt', product.title
    assert_equal promise1, promise2
    assert_nil GraphQL::Batch::Executor.current
  end
end
