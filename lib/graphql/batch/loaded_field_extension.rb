# frozen_string_literal: true

if Gem::Version.new(GraphQL::VERSION) < Gem::Version.new("1.9.0")
  raise "GraphQL::Batch::LoadedFieldExtension is not supported on graphql gem versions less than 1.9"
end

require_relative 'loaded_field_extension/loader'

module GraphQL::Batch
  # Resolve the field using a class method on the GraphQL::Schema::Object
  # for multiple instances. This avoids the need to extract the logic
  # out into a {GraphQL::Batch::Loader} and automatically groups selections
  # to load together.
  #
  # The class method must set the value on all given instances using an attribute
  # writer of the same name as the resolver method.
  #
  # @example
  #   class Product < GraphQL::Schema::Object
  #     field :inventory_quantity, Int, null: false do
  #       extension GraphQL::Batch::LoadedFieldExtension
  #     end
  #     def self.inventory_quantity(instances)
  #       product_ids = instances.map { |instance| instance.object.id }
  #       quantities = ProductVariant.group(:product_id).where(product_id: product_ids).sum(:inventory_quantity)
  #       instances.each do |instance|
  #         instance.inventory_quantity = quantities.fetch(instance.object.id, 0)
  #       end
  #     end
  #
  # For field selections to be loaded together, they must be given the same
  # arguments. If the lookahead extra is used on the field, then it will group
  # objects for the same selection set.
  class LoadedFieldExtension < GraphQL::Schema::FieldExtension
    def apply
      @iv_name = iv_name = :"@#{field.resolver_method}"
      resolver_method = field.resolver_method
      field.owner.class_eval do
        attr_writer(resolver_method)
      end
    end

    def resolve(object:, arguments:, context:)
      selections = if field.extras.include?(:lookahead)
        arguments.delete(:lookahead)
      elsif field.extras.include?(:irep_node)
        arguments.delete(:irep_node)
      end
      Loader.for(selections, object.class, field.resolver_method, arguments, @iv_name).load(object)
    end
  end
end
