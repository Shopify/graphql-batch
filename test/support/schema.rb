ImageType = GraphQL::ObjectType.define do
  name "Image"

  field :id, !types.ID
  field :filename, !types.String
end

ProductVariantType = GraphQL::ObjectType.define do
  name "ProductVariant"

  field :id, !types.ID
  field :title, !types.String
end

ProductType = GraphQL::ObjectType.define do
  name "Product"

  field :id, !types.ID
  field :title, !types.String

  field :images do
    type types[!ImageType]
    resolve -> (product, args, ctx) {
      product_image_query = FindQuery.new(model: Image, id: product.image_id)
      variant_images_query = AssociationQuery.new(owner: product, association: :variants) do |variants|
        variant_image_queries = variants.map do |variant|
          AssociationQuery.new(owner: variant, association: :images)
        end
        GraphQL::Batch::QueryGroup.new(variant_image_queries) do
          variant_image_queries.map(&:result).flatten
        end
      end
      GraphQL::Batch::QueryGroup.new([product_image_query, variant_images_query]) do
        [product_image_query.result] + variant_images_query.result
      end
    }
  end

  field :variants do
    type types[!ProductVariantType]
    resolve -> (product, args, ctx) {
      AssociationQuery.new(owner: product, association: :variants)
    }
  end

  field :variants_count do
    type types.Int
    resolve -> (product, args, ctx) {
      query = AssociationQuery.new(owner: product, association: :variants)
      GraphQL::Batch::QueryGroup.new([query]) { query.result.size }
    }
  end
end

QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :product do
    type ProductType
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      FindQuery.new(model: Product, id: args["id"])
    }
  end

  field :products do
    type types[!ProductType]
    argument :first, !types.Int
    resolve -> (obj, args, ctx) { Product.first(args["first"]) }
  end

  field :product_variants_count do
    type types.Int
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      FindQuery.new(model: Product, id: args["id"]) do |product|
        AssociationQuery.new(owner: product, association: :variants, &:size)
      end
    }
  end
end

Schema = GraphQL::Schema.new(query: QueryType)
Schema.query_execution_strategy = GraphQL::Batch::ExecutionStrategy
