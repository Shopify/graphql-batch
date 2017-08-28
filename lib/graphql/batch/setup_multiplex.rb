module GraphQL::Batch
  class SetupMultiplex
    def initialize(schema)
      @schema = schema
    end

    def before_multiplex(multiplex)
      Setup.start_batching
    end

    def after_multiplex(multiplex)
      Setup.end_batching
    end

    def instrument(type, field)
      Setup.instrument_field(@schema, type, field)
    end
  end
end
