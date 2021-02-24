class ImageType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :filename, String, null: false
end

class ProductVariantType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :title, String, null: false
  field :image_ids, [ID, null: true], null: false

  def image_ids
    AssociationLoader.for(ProductVariant, :images).load(object).then do |images|
      images.map(&:id)
    end
  end

  field :product, GraphQL::Schema::LateBoundType.new('Product'), null: false

  def product
    RecordLoader.for(Product).load(object.product_id)
  end
end

class ProductType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :title, String, null: false
  field :images, [ImageType], null: true

  def images
    product_image_query = RecordLoader.for(Image).load(object.image_id)
    variant_images_query = AssociationLoader.for(Product, :variants).load(object).then do |variants|
      variant_image_queries = variants.map do |variant|
        AssociationLoader.for(ProductVariant, :images).load(variant)
      end
      Promise.all(variant_image_queries).then(&:flatten)
    end
    Promise.all([product_image_query, variant_images_query]).then do
      [product_image_query.value] + variant_images_query.value
    end
  end

  field :non_null_but_raises, String, null: false

  def non_null_but_raises
    raise GraphQL::ExecutionError, 'Error'
  end

  field :variants, [ProductVariantType], null: true

  def variants
    AssociationLoader.for(Product, :variants).load(object)
  end

  field :variants_count, Int, null: true

  def variants_count
    query = AssociationLoader.for(Product, :variants).load(object)
    Promise.all([query]).then { query.value.size }
  end
end

class QueryType < GraphQL::Schema::Object
  field :constant, String, null: false

  def constant
    "constant value"
  end

  field :load_execution_error, String, null: true

  def load_execution_error
    RecordLoader.for(Product).load(1).then do |product|
      raise GraphQL::ExecutionError, "test error message"
    end
  end

  field :non_null_but_raises, ProductType, null: false

  def non_null_but_raises
    raise GraphQL::ExecutionError, 'Error'
  end

  field :non_null_but_promise_raises, String, null: false

  def non_null_but_promise_raises
    NilLoader.load.then do
      raise GraphQL::ExecutionError, 'Error'
    end
  end

  field :product, ProductType, null: true do
    argument :id, ID, required: true
  end

  def product(id:)
    RecordLoader.for(Product).load(id)
  end

  field :products, [ProductType], null: true do
    argument :first, Int, required: true
  end

  def products(first:)
    Product.first(first)
  end

  field :product_variants_count, Int, null: true do
    argument :id, ID, required: true
  end

  def product_variants_count(id:)
    RecordLoader.for(Product).load(id).then do |product|
      AssociationLoader.for(Product, :variants).load(product).then(&:size)
    end
  end
end

class CounterType < GraphQL::Schema::Object
  field :value, Int, null: false

  def value
    object
  end

  field :load_value, Int, null: false

  def load_value
    CounterLoader.load(context[:counter])
  end
end

class IncrementCounterMutation < GraphQL::Schema::Mutation
  null false
  payload_type CounterType

  def resolve
    context[:counter][0] += 1
    CounterLoader.load(context[:counter])
  end
end

class CounterLoaderMutation < GraphQL::Schema::Mutation
  null false
  payload_type Int

  def resolve
    CounterLoader.load(context[:counter])
  end
end

class NoOpMutation < GraphQL::Schema::Mutation
  null false
  payload_type QueryType

  def resolve
    Hash.new
  end
end

class MutationType < GraphQL::Schema::Object
  field :increment_counter, mutation: IncrementCounterMutation
  field :counter_loader, mutation: CounterLoaderMutation
  field :no_op, mutation: NoOpMutation
end

class Schema < GraphQL::Schema
  query QueryType
  mutation MutationType

  use GraphQL::Execution::Interpreter
  # This probably has no effect, but just to get the full test:
  use GraphQL::Analysis::AST
  use GraphQL::Batch
end
