# frozen_string_literal: true

module GraphQL::Batch
  class SetupMultiplex
    def initialize(schema, executor_class:)
      @schema = schema
      @executor_class = executor_class
    end

    def before_multiplex(_multiplex)
      Setup.start_batching(@executor_class)
    end

    def after_multiplex(_multiplex)
      Setup.end_batching
    end

    def instrument(type, field)
      Setup.instrument_field(@schema, type, field)
    end
  end
end
