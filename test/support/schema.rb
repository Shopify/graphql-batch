ImageType = GraphQL::ObjectType.define do
  name "Image"

  field :id, !types.ID
  field :filename, !types.String
end

ProductVariantType = GraphQL::ObjectType.define do
  name "ProductVariant"

  field :id, !types.ID
  field :title, !types.String
  field :image_ids, !types[types.ID] do
    resolve ->(variant, _, _) {
      AssociationLoader.for(ProductVariant, :images).load(variant).then do |images|
        images.map(&:id)
      end
    }
  end
end

ProductType = GraphQL::ObjectType.define do
  name "Product"

  field :id, !types.ID
  field :title, !types.String

  field :images do
    type types[!ImageType]
    resolve -> (product, args, ctx) {
      product_image_query = RecordLoader.for(Image).load(product.image_id)
      variant_images_query = AssociationLoader.for(Product, :variants).load(product).then do |variants|
        variant_image_queries = variants.map do |variant|
          AssociationLoader.for(ProductVariant, :images).load(variant)
        end
        Promise.all(variant_image_queries).then(&:flatten)
      end
      Promise.all([product_image_query, variant_images_query]).then do
        [product_image_query.value] + variant_images_query.value
      end
    }
  end

  field :nonNullButRaises do
    type !types.String
    resolve -> (_, _, _) {
      raise GraphQL::ExecutionError, 'Error'
    }
  end

  field :variants do
    type types[!ProductVariantType]
    resolve -> (product, args, ctx) {
      AssociationLoader.for(Product, :variants).load(product)
    }
  end

  field :variants_count do
    type types.Int
    resolve -> (product, args, ctx) {
      query = AssociationLoader.for(Product, :variants).load(product)
      Promise.all([query]).then { query.value.size }
    }
  end
end

QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :constant, !types.String do
    resolve ->(_, _, _) { "constant value" }
  end

  field :load_execution_error, types.String do
    resolve ->(_, _, _) {
      RecordLoader.for(Product).load(1).then do |product|
        raise GraphQL::ExecutionError, "test error message"
      end
    }
  end

  field :nonNullButRaises do
    type !ProductType
    resolve -> (_, _, _) {
      raise GraphQL::ExecutionError, 'Error'
    }
  end

  field :nonNullButPromiseRaises do
    type !types.String
    resolve -> (_, _, _) {
      NilLoader.load.then do
        raise GraphQL::ExecutionError, 'Error'
      end
    }
  end

  field :product do
    type ProductType
    argument :id, !types.ID
    resolve -> (obj, args, ctx) {
      RecordLoader.for(Product).load(args["id"])
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
      RecordLoader.for(Product).load(args["id"]).then do |product|
        AssociationLoader.for(Product, :variants).load(product).then(&:size)
      end
    }
  end
end

CounterType = GraphQL::ObjectType.define do
  name "Counter"

  field :value, !types.Int do
    resolve ->(obj, _, _) { obj }
  end

  field :load_value, !types.Int do
    resolve ->(_, _, ctx) { CounterLoader.for(ctx).load }
  end
end

MutationType = GraphQL::ObjectType.define do
  name "Mutation"

  field :increment_counter, !CounterType do
    resolve ->(_, _, ctx) { ctx[:counter][0] += 1; CounterLoader.for(ctx).load }
  end

  field :counter_loader, !types.Int do
    resolve ->(_, _, ctx) { CounterLoader.for(ctx).load }
  end
end

Schema = GraphQL::Schema.new(query: QueryType, mutation: MutationType)
Schema.query_execution_strategy = GraphQL::Batch::ExecutionStrategy
Schema.mutation_execution_strategy = GraphQL::Batch::MutationExecutionStrategy
