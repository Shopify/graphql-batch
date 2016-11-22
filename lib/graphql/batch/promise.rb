module GraphQL::Batch
  class Promise < ::Promise
    def defer
      executor = Executor.current
      executor ? executor.defer { super } : super
    end
  end
end
