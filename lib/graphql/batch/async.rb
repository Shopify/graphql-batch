module GraphQL::Batch
  module Async
    def resolve
      defer # Let other non-async loaders run to completion first.
      @peek_queue_index = 0 # The queue is consumed in super, future peeks will start from the beinning.
      super
    end

    def on_any_loader_wait
      @peek_queue_index ||= 0
      peek_queue = queue[@peek_queue_index..]
      return if peek_queue.empty?
      @peek_queue_index = peek_queue.size
      perform_early(peek_queue)
    end

    def perform_early(keys)
      raise NotImplementedError, "Implement GraphQL::Batch::Async#perform_early to trigger async operations early"
    end

    def perform(keys)
      raise NotImplementedError, "Implement GraphQL::Batch::Async#perform to wait on the async operations"
    end
  end
end
