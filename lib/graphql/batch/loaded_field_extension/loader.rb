# frozen_string_literal: true

require 'graphql/batch'

module GraphQL::Batch
  class LoadedFieldExtension < GraphQL::Schema::FieldExtension
    class Loader < GraphQL::Batch::Loader
      def self.loader_key_for(selections, object_class, resolver_method, arguments, iv_name)
        [self, selections&.ast_nodes, object_class, resolver_method, arguments]
      end

      def initialize(selections, object_class, resolver_method, arguments, iv_name)
        @selections = selections
        @object_class = object_class
        @resolver_method = resolver_method
        @arguments = arguments
        @iv_name = iv_name
      end

      def perform(instances)
        arguments = @arguments
        case @selections
        when nil
        when GraphQL::Execution::Lookahead
          arguments = arguments.merge(lookahead: @selections)
        when GraphQL::InternalRepresentation::Node
          arguments = arguments.merge(irep_node: @selections)
        end
        if arguments.empty?
          @object_class.public_send(@resolver_method, instances)
        else
          @object_class.public_send(@resolver_method, instances, arguments)
        end
        instances.each do |instance|
          if instance.instance_variable_defined?(@iv_name)
            value = instance.remove_instance_variable(@iv_name)
            fulfill(instance, value)
          else
            message = "Attribute #{@resolver_method} wasn't set by " \
              "#{@object_class}.#{@resolver_method} for object #{instance.object.inspect}"
            reject(instance, ::Promise::BrokenError.new(message))
          end
        end
      end
    end
    private_constant :Loader
  end
end
