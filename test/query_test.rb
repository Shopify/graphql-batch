require_relative 'test_helper'

class GraphQL::Batch::QueryTest < Minitest::Test
  class GroupCountQuery < GraphQL::Batch::Query
    def initialize(key, &block)
      @key = key
      super(&block)
    end

    def group_key
      @key
    end

    def self.execute(queries)
      queries.each do |query|
        query.complete(queries.size)
      end
    end
  end

  class EchoQuery < GraphQL::Batch::Query
    attr_reader :value

    def initialize(value, &block)
      @value = value
      super(&block)
    end

    def group_key
      object_id
    end

    def self.execute(queries)
      queries.each do |query|
        query.complete(query.value)
      end
    end
  end


  def test_single_query
    assert_equal 1, GroupCountQuery.new("single").execute
  end

  def test_query_group
    group = GraphQL::Batch::QueryGroup.new([
      GroupCountQuery.new("two"),
      GroupCountQuery.new("one"),
      GroupCountQuery.new("two"),
    ])
    assert_equal [2, 1, 2], group.execute
  end

  def test_empty_group_query
    assert_equal [], GraphQL::Batch::QueryGroup.new([]).execute
  end

  def test_group_query_with_non_queries
    assert_equal [1, :a, 'b'], GraphQL::Batch::QueryGroup.new([1, :a, 'b']).execute
  end

  def test_group_query_with_some_queries
    group = GraphQL::Batch::QueryGroup.new([
      GroupCountQuery.new("two"),
      'one',
      GroupCountQuery.new("two"),
    ])
    assert_equal [2, 'one', 2], group.execute
  end

  def test_then
    assert_equal 3, GroupCountQuery.new("single").then { |value| value + 2 }.execute
  end

  def test_then_error
    query = GroupCountQuery.new("single").then { raise "oops" }
    assert_raises(RuntimeError, 'oops') do
      query.execute
    end
  end

  def test_rescue_without_error
    assert_equal 3, GroupCountQuery.new("single").then { |value| value + 2 }.rescue { |err| err.message }.execute
  end

  def test_rescue_with_error
    query = GroupCountQuery.new("single").then { raise "oops" }.rescue { |err| err.message }
    assert_equal 'oops', query.execute
  end

  def test_ensure
    ensure_args = nil
    query = GroupCountQuery.new("single").ensure do |value, error|
      ensure_args = [value, error]
      value + 2
    end
    assert_equal 1, query.execute
    assert_equal [1, nil], ensure_args
  end

  def test_ensure_with_error
    ensure_args = nil
    query = GroupCountQuery.new("single").then { raise "oops" }.ensure do |value, error|
      ensure_args = [value, error]
      error.message
    end
    assert_raises(RuntimeError, "oops") { query.execute }
    assert_nil ensure_args[0]
    assert_equal "oops", ensure_args[1].message
  end

  def test_query_in_callback
    assert_equal 5, EchoQuery.new(4).then { |value| EchoQuery.new(value + 1) }.execute
  end
end
