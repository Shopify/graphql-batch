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
    attr_reader :value

    def perform(keys)
      keys.each { |key| fulfill(key, key) }
    end
  end


  def teardown
    GraphQL::Batch::Executor.current.clear
  end


  def test_single_query
    assert_equal 1, GroupCountLoader.for('single').load('first').sync
  end

  def test_query_group
    group = GraphQL::Batch::Promise.all([
      GroupCountLoader.for('two').load(:a),
      GroupCountLoader.for('one').load(:a),
      GroupCountLoader.for('two').load(:b),
    ])
    assert_equal [2, 1, 2], group.sync
  end

  def test_empty_group_query
    assert_equal [], GraphQL::Batch::Promise.all([]).sync
  end

  def test_group_query_with_non_queries
    assert_equal [1, :a, 'b'], GraphQL::Batch::Promise.all([1, :a, 'b']).sync
  end

  def test_group_query_with_some_queries
    group = GraphQL::Batch::Promise.all([
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
    assert_raises(RuntimeError, 'oops') do
      query.sync
    end
  end

  def test_on_reject_without_error
    assert_equal 3, GroupCountLoader.for("single").load(:a).then { |value| value + 2 }.then(nil, ->(err) { err.message }).sync
  end

  def test_rescue_with_error
    query = GroupCountLoader.for("single").load(:a).then { raise "oops" }.then(nil, ->(err) { err.message })
    assert_equal 'oops', query.sync
  end

  def test_query_in_callback
    assert_equal 5, EchoLoader.for().load(4).then { |value| EchoLoader.for().load(value + 1) }.sync
  end
end
