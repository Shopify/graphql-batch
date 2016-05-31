class QueryNotifier
  class << self
    attr_accessor :subscriber

    def call(query)
      subscriber && subscriber.call(query)
    end
  end
end

module ModelClassMethods
  attr_accessor :fixtures, :has_manys

  def first(count)
    QueryNotifier.call("#{name}?limit=#{count}")
    fixtures.values.first(count).map(&:dup)
  end

  def find(ids)
    ids = Array(ids)
    QueryNotifier.call("#{name}/#{ids.join(',')}")
    ids.map{ |id| fixtures[id] }.compact.map(&:dup)
  end

  def preload_association(owners, association)
    association_reflection = reflect_on_association(association)
    foreign_key = association_reflection[:foreign_key]
    scope = association_reflection[:scope]
    rows = association_reflection[:model].fixtures.values
    owner_ids = owners.map(&:id).to_set

    QueryNotifier.call("#{name}/#{owners.map(&:id).join(',')}/#{association}")
    records = rows.select{ |row|
      owner_ids.include?(row.public_send(foreign_key)) && scope.call(row)
    }

    records_by_key = records.group_by(&foreign_key)
    owners.each do |owner|
      owner.public_send("#{association}=", records_by_key[owner.id] || [])
    end
    nil
  end

  def has_many(association_name, model:, foreign_key:, scope: ->(row){ true })
    self.has_manys ||= {}
    has_manys[association_name] = { model: model, foreign_key: foreign_key, scope: scope }
    attr_accessor(association_name)
  end

  def reflect_on_association(association)
    has_manys.fetch(association)
  end
end

Image = Struct.new(:id, :owner_type, :owner_id, :filename) do
  extend ModelClassMethods
end

ProductVariant = Struct.new(:id, :product_id, :title) do
  extend ModelClassMethods
  has_many :images, model: Image, foreign_key: :owner_id, scope: ->(row) { row.owner_type == 'ProductVariant' }
end

Product = Struct.new(:id, :title, :image_id) do
  extend ModelClassMethods
  has_many :variants, model: ProductVariant, foreign_key: :product_id
end

Product.fixtures = [
  Product.new(1, "Shirt", 1),
  Product.new(2, "Pants", 2),
  Product.new(3, "Sweater", 3),
].each_with_object({}){ |p, h| h[p.id] = p }

ProductVariant.fixtures = [
  ProductVariant.new(1, 1, "Red"),
  ProductVariant.new(2, 1, "Blue"),
  ProductVariant.new(4, 2, "Small"),
  ProductVariant.new(5, 2, "Medium"),
  ProductVariant.new(6, 2, "Large"),
  ProductVariant.new(7, 3, "Default"),
].each_with_object({}){ |p, h| h[p.id] = p }

Image.fixtures = [
  Image.new(1, 'Product', 1, "shirt.jpg"),
  Image.new(2, 'Product', 2, "pants.jpg"),
  Image.new(3, 'Product', 3, "sweater.jpg"),
  Image.new(4, 'ProductVariant', 1, "red-shirt.jpg"),
  Image.new(5, 'ProductVariant', 2, "blue-shirt.jpg"),
  Image.new(6, 'ProductVariant', 3, "small-pants.jpg"),
].each_with_object({}){ |p, h| h[p.id] = p }
