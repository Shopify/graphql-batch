$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'graphql/batch'

require_relative 'support/loaders'
require_relative 'support/schema'
require_relative 'support/db'

require 'minitest/autorun'

if ENV["GRAPHQL_FUTURE"] == "YES"
  puts "Using execute_next by default"
  GraphQL::Schema.class_exec do
    use GraphQL::Execution::Next
    class << self
      alias_method :execute_legacy, :execute
      alias_method :execute, :execute_next
    end
  end
end
