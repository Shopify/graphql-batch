module GraphQL::Batch
  Promise = ::Promise
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.3")
    deprecate_constant :Promise
  end
end
