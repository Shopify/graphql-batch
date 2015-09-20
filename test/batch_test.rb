require_relative 'test_helper'

class Graphql::BatchTest < Minitest::Test
  def setup
    QUERIES.clear
  end

  def test_single_query
    query_string = <<-GRAPHQL
      {
        product(id: "1") {
          id
          title
        }
      }
    GRAPHQL
    result = Schema.execute(query_string, debug: true)
    expected = {
      "data" => {
        "product" => {
          "id" => "1",
          "title" => "Shirt",
        }
      }
    }
    assert_equal expected, result
    assert_equal ["Product/1"], QUERIES
  end

  def test_batched_find_by_id
    query_string = <<-GRAPHQL
      {
        product1: product(id: "1") { id, title }
        product2: product(id: "2") { id, title }
      }
    GRAPHQL
    result = Schema.execute(query_string, debug: true)
    expected = {
      "data" => {
        "product1" => { "id" => "1", "title" => "Shirt" },
        "product2" => { "id" => "2", "title" => "Pants" },
      }
    }
    assert_equal expected, result
    assert_equal ["Product/1,2"], QUERIES
  end

  def test_batched_association_preload
    query_string = <<-GRAPHQL
      {
        products(first: 2) {
          id
          title
          variants {
            id
            title
          }
        }
      }
    GRAPHQL
    result = Schema.execute(query_string, debug: true)
    expected = {
      "data" => {
        "products" => [
          {
            "id" => "1",
            "title" => "Shirt",
            "variants" => [
              { "id" => "1", "title" => "Red" },
              { "id" => "2", "title" => "Blue" },
              { "id" => "3", "title" => "Green" },
            ],
          },
          {
            "id" => "2",
            "title" => "Pants",
            "variants" => [
              { "id" => "4", "title" => "Small" },
              { "id" => "5", "title" => "Medium" },
              { "id" => "6", "title" => "Large" },
            ],
          }
        ]
      }
    }
    assert_equal expected, result
    assert_equal ["Product?limit=2", "Product/1,2/variants"], QUERIES
  end
end
