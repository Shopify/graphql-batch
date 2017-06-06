require_relative 'test_helper'

class GraphQL::MultiplexTest < Minitest::Test
  attr_reader :queries

  def setup
    @queries = []
    QueryNotifier.subscriber = ->(query) { @queries << query }
  end

  def teardown
    QueryNotifier.subscriber = nil
  end

  def schema_multiplex(*args)
    ::Schema.multiplex(*args)
  end


  def test_batched_find_by_id
    query_string = <<-GRAPHQL
      query FetchTwoProducts($id1: ID!, $id2: ID!){
        first: product(id: $id1) { id, title }
        second: product(id: $id2) { id, title }
      }
    GRAPHQL

    results = schema_multiplex([
      { query: query_string, variables: { "id1" => "1", "id2" => "2"} },
      { query: query_string, variables: { "id1" => "1", "id2" => "3"}},
    ])

    expected_1 = {
      "data" => {
        "first" => { "id" => "1", "title" => "Shirt" },
        "second" => { "id" => "2", "title" => "Pants" },
      }
    }

    expected_2 = {
      "data" => {
        "first" => { "id" => "1", "title" => "Shirt" },
        "second" => { "id" => "3", "title" => "Sweater" },
      }
    }

    assert_equal expected_1, results.first
    assert_equal expected_2, results.last
    assert_equal ["Product/1,2,3"], queries
  end
end
