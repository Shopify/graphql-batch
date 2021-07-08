require_relative 'test_helper'

class GraphQL::Batch::LoaderTest < Minitest::Test
  class GroupCountLoader < GraphQL::Batch::Loader
    def initialize(key)
    end

    def perform(keys)
      keys.each { |key| fulfill(key, keys.size) }
    end
  end

  class EchoLoader < GraphQL::Batch::Loader
    def perform(keys)
      keys.each { |key| fulfill(key, key) }
    end
  end

  class IncrementLoader < GraphQL::Batch::Loader
    def perform(keys)
      keys.each { |key| fulfill(key, key + 1) }
    end
  end

  class BrokenLoader < GraphQL::Batch::Loader
    def perform(keys)
    end
  end

  class NestedLoader < GraphQL::Batch::Loader
    def perform(keys)
      keys.each { |key| fulfill(key, EchoLoader.load(key)) }
    end
  end

  class DerivedCacheKeyLoader < EchoLoader
    def cache_key(load_key)
      load_key.to_s
    end
  end

  class ExplodingLoader < GraphQL::Batch::Loader
    def perform(_keys)
      raise 'perform failed'
    end
  end

  def setup
    GraphQL::Batch::Executor.current = GraphQL::Batch::Executor.new
  end

  def teardown
    GraphQL::Batch::Executor.current = nil
  end

  def test_no_executor
    GraphQL::Batch::Executor.current = nil

    assert_raises(GraphQL::Batch::NoExecutorError) do
      EchoLoader.for
    end
  end

  def test_single_query
    assert_equal 1, GroupCountLoader.for('single').load('first').sync
  end

  def test_query_group
    group = Promise.all([
      GroupCountLoader.for('two').load(:a),
      GroupCountLoader.for('one').load(:a),
      GroupCountLoader.for('two').load(:b),
    ])
    assert_equal [2, 1, 2], group.sync
  end

  def test_query_many
    assert_equal [:a, :b, :c], EchoLoader.load_many([:a, :b, :c]).sync
  end

  def test_empty_group_query
    assert_equal [], Promise.all([]).sync
  end

  def test_group_query_with_non_queries
    assert_equal [1, :a, 'b'], Promise.all([1, :a, 'b']).sync
  end

  def test_group_query_with_some_queries
    group = Promise.all([
      GroupCountLoader.for("two").load(:a),
      'one',
      GroupCountLoader.for("two").load(:b),
    ])
    assert_equal [2, 'one', 2], group.sync
  end

  def test_then
    assert_equal 3, GroupCountLoader.for("single").load(:a).then { |value| value + 2 }.sync
  end

  def test_then_error
    query = GroupCountLoader.for("single").load(:a).then { raise "oops" }
    err = assert_raises(RuntimeError) do
      query.sync
    end
    assert_equal 'oops', err.message
  end

  def test_on_reject_without_error
    assert_equal 3, GroupCountLoader.for("single").load(:a).then { |value| value + 2 }.then(nil, ->(err) { err.message }).sync
  end

  def test_rescue_with_error
    query = GroupCountLoader.for("single").load(:a).then { raise "oops" }.then(nil, ->(err) { err.message })
    assert_equal 'oops', query.sync
  end

  def test_query_in_callback
    assert_equal 5, EchoLoader.load(4).then { |value| EchoLoader.load(value + 1) }.sync
  end

  def test_broken_promise_loader_check
    promise = BrokenLoader.load(1)
    promise.wait
    assert_equal GraphQL::Batch::BrokenPromiseError, promise.reason.class
    assert_equal "#{BrokenLoader.name} didn't fulfill promise for key 1", promise.reason.message
  end

  def test_nested_promise_loader_check
    promise = NestedLoader.load(1)
    promise.wait
    assert_equal false, promise.pending?
    assert_equal false, promise.rejected?
    assert_equal true, promise.fulfilled?
    assert_equal 1, promise.value
  end

  def test_loader_class_grouping
    group = Promise.all([
      EchoLoader.load(:a),
      IncrementLoader.load(1),
    ])
    assert_equal [:a, 2], group.sync
  end

  def test_load_after_perform
    loader = EchoLoader.for
    promise1 = loader.load(:a)
    assert_equal :a, promise1.sync
    assert_equal :b, loader.load(:b).sync
    assert_equal promise1, loader.load(:a)
  end

  def test_load_on_different_loaders
    loader = EchoLoader.for
    assert_equal :a, loader.load(:a).sync
    loader2 = EchoLoader.for

    promise = loader2.load(:b)
    promise2 = loader.load(:c)

    assert_equal :b, promise.sync
    assert_equal :c, promise2.sync
  end

  def test_derived_cache_key
    assert_equal [:a, :b, :a], DerivedCacheKeyLoader.load_many([:a, :b, "a"]).sync
  end

  def test_loader_for_without_load
    loader = EchoLoader.for
    GraphQL::Batch::Executor.current.wait_all
  end

  def test_loader_without_executor
    loader1 = GroupCountLoader.new('one')
    loader2 = GroupCountLoader.new('two')
    group = Promise.all([
      loader2.load(:a),
      loader1.load(:a),
      loader2.load(:b),
    ])
    assert_equal [2, 1, 2], group.sync
  end

  def test_loader_with_failing_perform
    error_message = nil
    promise = ExplodingLoader.load([1]).then(nil, ->(err) { error_message = err.message } ).sync
    assert_equal 'perform failed', error_message
  end
end
