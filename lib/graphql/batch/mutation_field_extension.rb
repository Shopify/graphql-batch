module GraphQL::Batch
  class MutationFieldExtension < GraphQL::Schema::FieldExtension
    def resolve(object: nil, objects: nil, arguments:, **_rest)
      GraphQL::Batch::Executor.current.clear
      begin
        if object
          ::Promise.sync(yield(object, arguments))
        else
          ::Promise.sync(yield(objects, arguments))
        end
      ensure
        GraphQL::Batch::Executor.current.clear
      end
    end
  end
end
