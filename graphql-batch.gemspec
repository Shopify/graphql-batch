require_relative 'lib/graphql/batch/version'

Gem::Specification.new do |spec|
  spec.name          = "graphql-batch"
  spec.version       = GraphQL::Batch::VERSION
  spec.authors       = ["Dylan Thacker-Smith"]
  spec.email         = ["gems@shopify.com"]

  spec.summary       = "A query batching executor for the graphql gem"
  spec.homepage      = "https://github.com/Shopify/graphql-batch"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.metadata['allowed_push_host'] = "https://rubygems.org"

  spec.add_runtime_dependency "graphql", ">= 1.12.18", "< 3"
  spec.add_runtime_dependency "promise.rb", "~> 0.7.2"

  spec.add_development_dependency "byebug" if RUBY_ENGINE == 'ruby'
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest"
end
