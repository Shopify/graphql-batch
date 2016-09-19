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

Define a custom loader, which is initialized with arguments that are used for grouping and a perform method for performing the batch load.

```ruby
class RecordLoader < GraphQL::Batch::Loader
  def initialize(model)
    @model = model
  end

  def perform(ids)
    @model.where(id: ids).each { |record| fulfill(record.id, record) }
    ids.each { |id| fulfill(id, nil) unless fulfilled?(id) }
  end
end
```

Use the batch execution strategy with your schema

```ruby
MySchema = GraphQL::Schema.new(query: MyQueryType)
MySchema.query_execution_strategy = GraphQL::Batch::ExecutionStrategy
MySchema.mutation_execution_strategy = GraphQL::Batch::MutationExecutionStrategy
```

The loader class can be used from the resolve proc for a graphql field by calling `.for` with the grouping arguments to get a loader instance, then call `.load` on that instance with the key to load.

```ruby
resolve -> (obj, args, context) { RecordLoader.for(Product).load(args["id"]) }
```

### Promises

GraphQL::Batch::Loader#load returns a Promise using the [promise.rb gem](https://rubygems.org/gems/promise.rb) to provide a promise based API, so you can transform the query results using `.then`

```ruby
resolve -> (obj, args, context) do
  RecordLoader.for(Product).load(args["id"]).then do |product|
    product.title
  end
end
```

You may also need to do another query that depends on the first one to get the result, in which case the query block can return another query.

```ruby
resolve -> (obj, args, context) do
  RecordLoader.for(Product).load(args["id"]).then do |product|
    RecordLoader.for(Image).load(product.image_id)
  end
end
```

If the second query doesn't depend on the first one, then you can use Promise.all, which allows each query in the group to be batched with other queries.

```ruby
resolve -> (obj, args, context) do
  Promise.all([
    CountLoader.for(Shop, :smart_collections).load(context.shop_id),
    CountLoader.for(Shop, :custom_collections).load(context.shop_id),
  ]).then do |results|
    results.reduce(&:+)
  end
end
```

`.then` can optionally take two lambda arguments, the first of which is equivalent to passing a block to `.then`, and the second one handles exceptions.  This can be used to provide a fallback

```ruby
resolve -> (obj, args, context) do
  CacheLoader.for(Product).load(args["id"]).then(nil, lambda do |exc|
    raise exc unless exc.is_a?(Redis::BaseConnectionError)
    logger.warn err.message
    RecordLoader.for(Product).load(args["id"])
  end)
end
```

## Unit Testing

GraphQL::Batch::Promise#sync can be used to wait for a promise to be resolved and return its result. This can be useful for debugging and unit testing loaders.

```ruby
  def test_single_query
    product = products(:snowboard)
    query = RecordLoader.for(Product).load(args["id"]).then(&:title)
    assert_equal product.title, query.sync
  end
```

Use GraphQL::Batch::Promise.all instead of Promise.all to be able to call sync on the returned promise.

```
  def test_batch_query
    products = [products(:snowboard), products(:jacket)]
    query1 = RecordLoader.for(Product).load(products(:snowboard).id).then(&:title)
    query2 = RecordLoader.for(Product).load(products(:jacket).id).then(&:title)
    results = GraphQL::Batch::Promise.all([query1, query2]).sync
    assert_equal products(:snowboard).title, results[0]
    assert_equal products(:jacket).title, results[1]
  end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/graphql-batch.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
