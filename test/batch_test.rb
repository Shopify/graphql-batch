require_relative 'test_helper'

class GraphQL::BatchTest < Minitest::Test
  def setup
    QUERIES.clear
  end

  def test_no_queries
    query_string = '{ constant }'
    result = Schema.execute(query_string, debug: true)
    expected = {
      "data" => {
        "constant" => "constant value"
      }
    }
    assert_equal expected, result
    assert_equal [], QUERIES
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

  def test_record_missing
    query_string = <<-GRAPHQL
      {
        product(id: "123") {
          id
          title
        }
      }
    GRAPHQL
    result = Schema.execute(query_string, debug: true)
    expected = { "data" => { "product" => nil } }
    assert_equal expected, result
    assert_equal ["Product/123"], QUERIES
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

  def test_query_group_with_single_query
    query_string = <<-GRAPHQL
      {
        products(first: 2) {
          id
          title
          variants_count
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
            "variants_count" => 2,
            "variants" => [
              { "id" => "1", "title" => "Red" },
              { "id" => "2", "title" => "Blue" },
            ],
          },
          {
            "id" => "2",
            "title" => "Pants",
            "variants_count" => 3,
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

  def test_sub_queries
    query_string = <<-GRAPHQL
      {
        product_variants_count(id: "2")
      }
    GRAPHQL
    result = Schema.execute(query_string, debug: true)
    expected = {
      "data" => {
        "product_variants_count" => 3
      }
    }
    assert_equal expected, result
    assert_equal ["Product/2", "Product/2/variants"], QUERIES
  end

  def test_query_group_with_sub_queries
    query_string = <<-GRAPHQL
      {
        product(id: "1") {
          images { id, filename }
        }
      }
    GRAPHQL
    result = Schema.execute(query_string, debug: true)
    expected = {
      "data" => {
        "product" => {
          "images" => [
            { "id" => "1", "filename" => "shirt.jpg" },
            { "id" => "4", "filename" => "red-shirt.jpg" },
            { "id" => "5", "filename" => "blue-shirt.jpg" },
          ]
        }
      }
    }
    assert_equal expected, result
    assert_equal ["Product/1", "Image/1", "Product/1/variants", "ProductVariant/1,2/images"], QUERIES
  end

  def test_load_list_of_objects_with_loaded_field
    query_string = <<-GRAPHQL
      {
        products(first: 2) {
          id
          variants {
            id
            image_ids
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
            "variants" => [
              { "id" => "1", "image_ids" => ["4"] },
              { "id" => "2", "image_ids" => ["5"] },
            ],
          },
          {
            "id" => "2",
            "variants" => [
              { "id" => "4", "image_ids" => [] },
              { "id" => "5", "image_ids" => [] },
              { "id" => "6", "image_ids" => [] },
            ],
          }
        ]
      }
    }
    assert_equal expected, result
    assert_equal ["Product?limit=2", "Product/1,2/variants", "ProductVariant/1,2,4,5,6/images"], QUERIES
  end

  def test_load_error
    query_string = <<-GRAPHQL
      {
        constant
        load_execution_error
      }
    GRAPHQL
    result = Schema.execute(query_string, debug: true)
    expected = {
      "data" => { "constant"=>"constant value", "load_execution_error" => nil },
      "errors" => [{ "message" => "test error message", "locations"=>[{"line"=>3, "column"=>9}]}],
    }
    assert_equal expected, result
  end

  def test_mutation_execution
    query_string = <<-GRAPHQL
      mutation {
        count1: counter_loader
        incr1: increment_counter { value, load_value }
        count2: counter_loader
        incr2: increment_counter { value, load_value }
      }
    GRAPHQL
    result = Schema.execute(query_string, context: { counter: [0] }, debug: true)
    expected = {
      "data" => {
        "count1" => 0,
        "incr1" => { "value" => 1, "load_value" => 1 },
        "count2" => 1,
        "incr2" => { "value" => 2, "load_value" => 2 },
      }
    }
    assert_equal expected, result
  end
end
