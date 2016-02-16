module GraphQL::Batch
  class Promise < ::Promise
    def wait
      Executor.current.wait(self)
    end
  end
end
