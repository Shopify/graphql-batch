ProductVariantType = GraphQL::ObjectType.define do
  name "ProductVariant"

  field :id, !types.ID
  field :title, !types.String
end

ProductType = GraphQL::ObjectType.define do
  name "Product"

  field :id, !types.ID
  field :title, !types.String

  field :variants do
    type types[!ProductVariantType]
    resolve -> (obj, args, ctx) {
      AssociationQuery.new(owner: obj, association: :variants)
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
end

Schema = GraphQL::Schema.new(query: QueryType)
Schema.query_execution_strategy = GraphQL::Batch::ExecutionStrategy
