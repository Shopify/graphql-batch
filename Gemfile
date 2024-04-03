source 'https://rubygems.org'

gemspec

gem 'graphql', ENV['GRAPHQL_VERSION'] if ENV['GRAPHQL_VERSION']
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.4.0')
  gem 'rubocop', '~> 1.61.0', require: false
  gem "rubocop-shopify", '~> 1.0.7', require: false
end
