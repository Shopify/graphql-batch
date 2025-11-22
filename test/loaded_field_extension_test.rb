# frozen_string_literal: true

require_relative 'test_helper'

# Only run tests for supported graphql gem versions
if Gem::Version.new(GraphQL::VERSION) >= Gem::Version.new("1.9.0")
  class GraphQL::Batch::LoadedFieldExtensionTest < Minitest::Test
    include QueryCollector

    class ImageType < GraphQL::Schema::Object
      field :id, ID, null: false
      field :filename, String, null: false
    end

    class ProductVariantType < GraphQL::Schema::Object
      field :id, ID, null: false
      field :title, String, null: false
    end

    class ProductType < GraphQL::Schema::Object
      field :id, ID, null: false

      field :variants, [ProductVariantType], null: true do
        argument :first, Int, required: true
        extension GraphQL::Batch::LoadedFieldExtension
      end
      def self.variants(instances, first:)
        products = instances.map(&:object)
        Product.preload_association(products, :variants)
        instances.each do |instance|
          instance.variants = instance.object.variants.first(first)
        end
      end

      field :variants_count, Int, null: false do
        extension GraphQL::Batch::LoadedFieldExtension
      end
      def self.variants_count(instances)
        products = instances.map(&:object)
        Product.preload_association(products, :variants)
        instances.each do |instance|
          instance.variants_count = instance.object.variants.length
        end
      end

      field :image, ImageType, null: false, extras: [:lookahead] do
        extension GraphQL::Batch::LoadedFieldExtension
      end
      def self.image(instances, lookahead:)
        if lookahead.selections.any? { |s| s.name != :id }
          ids = instances.map(&:object).map(&:image_id)
          images = Image.find(ids)
          instances.each do |instance|
            instance.image = images.detect { |image| image.id == instance.object.image_id }
          end
        else
          instances.each do |instance|
            product = instance.object
            instance.image = Image.new.tap { |image| image.id = product.image_id }
          end
        end
      end

      field :legacy_image, ImageType, null: false, extras: [:irep_node] do
        extension GraphQL::Batch::LoadedFieldExtension
      end
      def self.legacy_image(instances, irep_node:)
        if irep_node.scoped_children.values.flat_map(&:keys).any? { |key| key != 'id' }
          ids = instances.map(&:object).map(&:image_id)
          images = Image.find(ids)
          instances.each do |instance|
            instance.legacy_image = images.detect { |image| image.id == instance.object.image_id }
          end
        else
          instances.each do |instance|
            product = instance.object
            instance.legacy_image = Image.new.tap { |image| image.id = product.image_id }
          end
        end
      end

      field :buggy, Int, null: false do
        extension GraphQL::Batch::LoadedFieldExtension
      end
      def self.buggy(instances)
        instances.first.buggy = 1
      end
    end

    class QueryType < GraphQL::Schema::Object
      field :products, [ProductType], null: false do
        argument :first, Int, required: true
      end
      def products(first:)
        Product.first(first)
      end

      field :product, ProductType, null: true do
        argument :id, ID, required: true
      end
      def product(id:)
        Product.find(Integer(id)).first
      end
    end

    class Schema < GraphQL::Schema
      query QueryType

      if ENV["TESTING_INTERPRETER"] == "true"
        use GraphQL::Execution::Interpreter
      end

      use GraphQL::Batch
    end

    def test_scalar_field
      query_string = '{ products(first: 2) { id, variantsCount } }'
      result = Schema.execute(query_string).to_h
      expected = {
        "data" => {
          "products" => [
            { "id" => '1', "variantsCount" => 2 },
            { "id" => '2', "variantsCount" => 3 },
          ]
        }
      }
      assert_equal expected, result
      assert_equal ["Product?limit=2", "Product/1,2/variants"], queries
    end

    def test_selections_with_same_arguments
      query_string = <<~GRAPHQL
        {
          product1: product(id: "1") { variants(first: 1) { id } }
          product2: product(id: "2") { variants(first: 1) { title } }
        }
      GRAPHQL
      result = Schema.execute(query_string).to_h
      expected = {
        "data" => {
          "product1" => { "variants" => [{ "id" => '1' }] },
          "product2" => { "variants" => [{ "title" => 'Small' }] },
        }
      }
      assert_equal expected, result
      assert_equal ["Product/1", "Product/2", "Product/1,2/variants"], queries
    end

    def test_selections_with_different_arguments
      query_string = <<~GRAPHQL
        {
          product1: product(id: "1") { variants(first: 1) { id } }
          product2: product(id: "2") { variants(first: 2) { title } }
        }
      GRAPHQL
      result = Schema.execute(query_string).to_h
      expected = {
        "data" => {
          "product1" => { "variants" => [{ "id" => '1' }] },
          "product2" => { "variants" => [{ "title" => 'Small' }, { "title" => 'Medium' }] },
        }
      }
      assert_equal expected, result
      assert_equal ["Product/1", "Product/2", "Product/1/variants", "Product/2/variants"], queries
    end

    def test_lookahead_with_different_nested_selections
      query_string = <<~GRAPHQL
        {
          product1: product(id: "1") { image { filename } }
          product2: product(id: "2") { image { id } }
        }
      GRAPHQL
      result = Schema.execute(query_string).to_h
      expected = {
        "data" => {
          "product1" => { "image" => { "filename" => 'shirt.jpg' } },
          "product2" => { "image" => { "id" => '2' } },
        }
      }
      assert_equal expected, result
      assert_equal ["Product/1", "Product/2", "Image/1"], queries
    end

    def test_lookahead_with_shared_ast_nodes
      query_string = <<~GRAPHQL
        query {
          product1: product(id: "1") { ...ProductFields }
          product2: product(id: "2") { ...ProductFields }
        }
        fragment ProductFields on Product { image: legacyImage { filename } }
      GRAPHQL
      result = Schema.execute(query_string).to_h
      expected = {
        "data" => {
          "product1" => { "image" => { "filename" => 'shirt.jpg' } },
          "product2" => { "image" => { "filename" => 'pants.jpg' } },
        }
      }
      assert_equal expected, result
      assert_equal ["Product/1", "Product/2", "Image/1,2"], queries
    end

    def test_unset_value_error
      query_string = '{ products(first: 2) { buggy } }'
      error = assert_raises(::Promise::BrokenError) do
        Schema.execute(query_string).to_h
      end
      product = Product.first(2)[1]
      assert_equal error.message, "Attribute buggy wasn't set by #{ProductType}.buggy for object #{product.inspect}"
    end
  end
end
