require_relative 'test_helper'

class GraphQL::BatchTest < Minitest::Test
  def test_batch
    product = GraphQL::Batch.batch do
      RecordLoader.for(Product).load(1)
    end
    assert_equal 'Shirt', product.title
  end

  def test_nested_batch
    # TODO: Update this test?
    GraphQL::Batch.batch do
      assert_raises(GraphQL::Batch::NestedError) do
        GraphQL::Batch.batch {}
      end
    end
  end
end
