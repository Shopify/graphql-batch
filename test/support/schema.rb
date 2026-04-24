class ImageType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :filename, String, null: false
end

class ProductVariantType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :title, String, null: false
  field :image_ids, [ID, null: true], null: false, resolve_each: true

  def self.image_ids(object, _context)
    AssociationLoader.for(ProductVariant, :images).load(object).then do |images|
      images.map(&:id)
    end
  end

  def image_ids
    self.class.image_ids(object, context)
  end

  field :product, GraphQL::Schema::LateBoundType.new('Product'), null: false, resolve_each: true

  def self.product(object, _context)
    RecordLoader.for(Product).load(object.product_id)
  end

  def product
    self.class.product(object, context)
  end
end

class ProductType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :title, String, null: false
  field :images, [ImageType], null: true, resolve_each: true

  def self.images(object, _context)
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

  def images
    self.class.images(object, context)
  end

  field :non_null_but_raises, String, null: false, resolve_static: true

  def self.non_null_but_raises(_context)
    raise GraphQL::ExecutionError, 'Error'
  end

  def non_null_but_raises
    self.class.non_null_but_raises(context)
  end

  field :variants, [ProductVariantType], null: true, resolve_each: true

  def self.variants(object, _context)
    AssociationLoader.for(Product, :variants).load(object)
  end

  def variants
    self.class.variants(object, context)
  end

  field :variants_count, Int, null: true, resolve_each: true

  def self.variants_count(object, _context)
    query = AssociationLoader.for(Product, :variants).load(object)
    Promise.all([query]).then { query.value.size }
  end

  def variants_count
    self.class.variants_count(object, context)
  end
end

class QueryType < GraphQL::Schema::Object
  field :constant, String, null: false, resolve_static: true

  def self.constant(_context)
    "constant value"
  end

  def constant
    self.class.constant(context)
  end

  field :load_execution_error, String, null: true, resolve_static: true

  def self.load_execution_error(_context)
    RecordLoader.for(Product).load(1).then do |product|
      raise GraphQL::ExecutionError, "test error message"
    end
  end

  def load_execution_error
    self.class.load_execution_error(context)
  end

  field :non_null_but_raises, ProductType, null: false, resolve_static: true

  def self.non_null_but_raises(_context)
    raise GraphQL::ExecutionError, 'Error'
  end

  def non_null_but_raises
    self.class.non_null_but_raises(context)
  end

  field :non_null_but_promise_raises, String, null: false, resolve_static: true

  def self.non_null_but_promise_raises(_context)
    NilLoader.load.then do
      raise GraphQL::ExecutionError, 'Error'
    end
  end

  def non_null_but_promise_raises
    self.class.non_null_but_promise_raises(context)
  end

  field :product, ProductType, null: true, resolve_static: true do
    argument :id, ID, required: true
  end

  def self.product(_context, id:)
    RecordLoader.for(Product).load(id)
  end

  def product(id:)
    self.class.product(context, id: id)
  end

  field :products, [ProductType], null: true, resolve_static: true do
    argument :first, Int, required: true
  end

  def self.products(_context, first:)
    Product.first(first)
  end

  def products(first:)
    self.class.products(context, first: first)
  end

  field :product_variants_count, Int, null: true, resolve_static: true do
    argument :id, ID, required: true
  end

  def self.product_variants_count(_context, id:)
    RecordLoader.for(Product).load(id).then do |product|
      AssociationLoader.for(Product, :variants).load(product).then(&:size)
    end
  end

  def product_variants_count(id:)
    self.class.product_variants_count(context, id: id)
  end
end

class CounterType < GraphQL::Schema::Object
  field :value, Int, null: false, resolve_each: true

  def self.value(object, _context)
    object
  end

  def value
    self.class.value(object, context)
  end

  field :load_value, Int, null: false, resolve_static: true

  def self.load_value(context)
    CounterLoader.load(context[:counter])
  end

  def load_value
    self.class.load_value(context)
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

  use GraphQL::Batch
end
