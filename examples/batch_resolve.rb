# Shows you the field selection can be used for grouping
# which can be used to provide a simpler API for basic usage

require 'graphql/batch'

GraphQL::Field.accepts_definitions batch_resolve: GraphQL::Define.assign_metadata_key(:batch_resolve)

module GraphQL
  module BatchResolve
    def self.use(schema_defn)
      schema_defn.instrument(:field, FieldInstrumentation)
    end

    module FieldInstrumentation
      def self.instrument(type, field)
        batch_resolve = field.metadata[:batch_resolve]
        return field unless batch_resolve
        unless field.resolve_proc.is_a?(GraphQL::Field::Resolve::NameResolve)
          raise "Field #{field.name} provides both a resolve and batch_resolve proc. Only one can be provided"
        end
        field.redefine do
          resolve ->(obj, args, ctx) {
            BatchResolve::Loader.for(args, ctx, batch_resolve).load(obj)
          }
        end
      end
    end

    class Loader < GraphQL::Batch::Loader
      class << self
        def loader_key_for(args, context, resolve_proc)
          context.selection
        end
      end

      def initialize(args, context, resolve_proc)
        @args = args
        @context = context
        @resolve_proc = resolve_proc
      end

      def cache_key(object)
        object.object_id
      end

      def perform(objects)
        results = @resolve_proc.call(objects, @args, @context)
        objects.zip(results) do |object, result|
          fulfill(object, result)
        end
      end
    end
  end
end


## Example usage

NumberObjectType = GraphQL::ObjectType.define do
  name "NumberObject"

  field :rolling_sum, !types.String do
    batch_resolve ->(numbers, args, context) {
      sum = 0
      numbers.map do |num|
        sum += num
      end
    }
  end
end

QueryType = GraphQL::ObjectType.define do
  name "Query"

  field :numbers, !types[!NumberObjectType] do
    argument :from, !types.Int
    argument :to, !types.Int
    resolve ->(obj, args, ctx) {
      (args.from..args.to).to_a
    }
  end
end

Schema = GraphQL::Schema.define do
  query QueryType
  use GraphQL::Batch
  use GraphQL::BatchResolve
end

query = '{
  numbers(from: 4, to: 5) {
    rolling_sum
  }
  numbers2: numbers(from: 1, to: 2) {
    rolling_sum
  }
}'

puts Schema.execute(query, variables: {}).to_h
# {"data"=>{"numbers"=>[{"rolling_sum"=>"4"}, {"rolling_sum"=>"9"}], "numbers2"=>[{"rolling_sum"=>"1"}, {"rolling_sum"=>"3"}]}}
