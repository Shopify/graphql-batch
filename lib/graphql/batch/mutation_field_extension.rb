module GraphQL::Batch
  class MutationFieldExtension < GraphQL::Schema::FieldExtension
    def resolve(object: nil, objects: nil, arguments:, **_rest)
      GraphQL::Batch::Executor.current.clear
      begin
        if !objects.nil?
          ::Promise.sync(yield(objects, arguments))
        else
          ::Promise.sync(yield(object, arguments))
        end
      ensure
        GraphQL::Batch::Executor.current.clear
      end
    end
  end
end
