QUERIES = []

Product = Struct.new(:id, :title) do
  attr_accessor :variants

  def self.first(count)
    QUERIES << "Product?limit=#{count}"
    PRODUCTS.values.first(count).map(&:dup)
  end

  def self.find(ids)
    ids = Array(ids)
    QUERIES << "Product/#{ids.join(',')}"
    ids.map{ |id| PRODUCTS[id].dup }.compact
  end

  def self.reflect_on_association(association)
    {
      variants: { rows: PRODUCT_VARIANTS.values, foreign_key: :product_id }
    }.fetch(association)
  end

  def self.preload_association(products, association)
    association_reflection = reflect_on_association(association)
    foreign_key = association_reflection[:foreign_key]
    rows = association_reflection[:rows]
    product_ids = products.map(&:id).to_set

    QUERIES << "Product/#{products.map(&:id).join(',')}/variants"
    records = rows.select{ |p| product_ids.include?(p.public_send(foreign_key)) }

    records_by_key = records.group_by(&foreign_key)
    products.each do |owner|
      owner.public_send("#{association}=", records_by_key[owner.id] || [])
    end
    nil
  end
end

ProductVariant = Struct.new(:id, :product_id, :title)

PRODUCTS = [
  Product.new(1, "Shirt"),
  Product.new(2, "Pants"),
  Product.new(3, "Sweater"),
].each_with_object({}){ |p, h| h[p.id] = p }

PRODUCT_VARIANTS = [
  ProductVariant.new(1, 1, "Red"),
  ProductVariant.new(2, 1, "Blue"),
  ProductVariant.new(4, 2, "Small"),
  ProductVariant.new(5, 2, "Medium"),
  ProductVariant.new(6, 2, "Large"),
  ProductVariant.new(7, 3, "Default"),
].each_with_object({}){ |p, h| h[p.id] = p }
