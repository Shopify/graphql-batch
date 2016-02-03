# GraphQL::Batch

Provides an executor for the [`graphql` gem](https://github.com/rmosolgo/graphql-ruby) which allows queries to be batched.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'graphql-batch'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install graphql-batch

## Usage

### Basic Usage

Require the library

```ruby
require 'graphql/batch'
```

Define a GraphQL::Batch::Query derived class. Use group_key to specify which queries can be reduced into a batch query, and an execute class method which makes that batch query and passes the result to each individual query.

```ruby
class FindQuery < GraphQL::Batch::Query
  attr_reader :model, :id

  def initialize(model, id, &block)
    @model = model
    @id = id
    super(&block)
  end

  # super returns the class name
  def group_key
    "#{super}:#{model.name}"
  end

  def self.execute(queries)
    model = queries.first.model
    ids = queries.map(&:id)
    records_by_id = model.where(id: ids).index_by(&:id)
    queries.each do |query|
      query.complete(records_by_id[query.id])
    end
  end
end
```

When defining your schema, using the graphql gem, return a your batch query object from the resolve proc.

```ruby
resolve -> (obj, args, context) { FindQuery.new(Product, args["id"]) }
```

Use the batch execution strategy with your schema

```ruby
MySchema = GraphQL::Schema.new(query: MyQueryType)
MySchema.query_execution_strategy = GraphQL::Batch::ExecutionStrategy
```

### Query Dependant Computed Fields

If you don't want to use a query result directly, then you can use `.then` with a block to transform the query result.

```ruby
resolve -> (obj, args, context) do
  FindQuery.new(Product, args["id"]).then do |product|
    product.title
  end
end
```

You may also need to do another query that depends on the first one to get the result, in which case the query block can return another query.

```ruby
resolve -> (obj, args, context) do
  FindQuery.new(Product, args["id"]).then do |product|
    FindQuery.new(Image, product.image_id)
  end
end
```

If the second query doesn't depend on the other one, then you can use GraphQL::Batch::QueryGroup, which allows each query in the group to be batched with other queries.

```ruby
resolve -> (obj, args, context) do
  QueryGroup.new([smart_collection_query, custom_collection_query]).then do |results|
    results.reduce(&:+)
  end
end

### Error Handling

Exceptions can be rescued by using `.rescue(error_class)` instead of `.then` which could be used for a fallback

```ruby
resolve -> (obj, args, context) do
  CacheFetchQuery.new(Product, args["id"]).rescue(Redis::BaseConnectionError) do |err|
    logger.warn err.message
    FindQuery.new(Product, args["id"])
  end
end
```

If you want to do something after the query without affecting the result, then you can use `.ensure` which could be used for instrumentation

```ruby
resolve -> (obj, args, context) do
  t0 = Time.now
  FindQuery.new(Product, args["id"]).ensure do |result, error|
    duration = Time.now - t0
    logger.info "Product load completed in #{duration} seconds"
  end
end
```

## Unit Testing

Batch query objects have an execute method to simplify unit testing and debugging by allowing batch queries to be executed without having to define a graphql schema.

```ruby
  def test_single_query
    product = products(:snowboard)
    assert_equal product.title, FindQuery.new(Product, args["id"]).then(&:title).execute
  end

  def test_batch_query
    products = [products(:snowboard), products(:jacket)]
    query1 = FindQuery.new(Product, products(:snowboard).id).then(&:title)
    query2 = FindQuery.new(Product, products(:jacket).id).then(&:title)
    group_query = QueryGroup.new([query1, query2]).execute
    assert_equal products(:snowboard).title, query1.result
    assert_equal products(:jacket).title, query2.result
  end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/graphql-batch.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
