require_relative 'test_helper'

class GraphQL::BatchTest < Minitest::Test
  def test_batch
    product = GraphQL::Batch.batch do
      RecordLoader.for(Product).load(1)
    end
    assert_equal 'Shirt', product.title
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
