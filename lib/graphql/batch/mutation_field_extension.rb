module GraphQL::Batch
  class MutationFieldExtension < GraphQL::Schema::FieldExtension
    def resolve(object:, arguments:, **_rest)
      GraphQL::Batch::Executor.current.clear
      begin
        ::Promise.sync(yield(object, arguments))
      ensure
        GraphQL::Batch::Executor.current.clear
      end
    end

    def after_resolve(value:, **_rest)
      GraphQL::Batch::Executor.current.clear
      value
    end
  end
end
