# A sample HTTP loader using:
#
# 1. https://github.com/httprb/http
# 2. https://github.com/mperham/connection_pool
# 3. https://github.com/ruby-concurrency/concurrent-ruby
#
# Setup:
#
#   field :weather, String, null: true do
#     argument :lat, Float, required: true
#     argument :lng, Float, required: true
#     argument :lang, String, required: true
#   end
#
#   def weather(lat:, lng:, lang:)
#     key = Rails.application.credentials.darksky_key
#     path = "/forecast/#{key}/#{lat},#{lng}?lang=#{lang}"
#     Loaders::HTTPLoader
#       .for(host: 'https://api.darksky.net')
#       .load(->(connection) { connection.get(path).flush })
#       .then do |response|
#         if response.status.ok?
#           json = JSON.parse(response.body)
#           json['currently']['summary']
#         end
#       end
#   end
#
# Querying:
#
#   <<~GQL
#     query Weather {
#       montreal: weather(lat: 45.5017, lng: -73.5673, lang: "fr")
#       waterloo: weather(lat: 43.4643, lng: -80.5204, lang: "en")
#     }
#   GQL

# An example loader which is blocking and synchronous as a whole, but executes all of its operations concurrently.
module Loaders
  class HTTPLoader < GraphQL::Batch::Loader
    def initialize(host:, size: 4, timeout: 4)
      super()
      @host = host
      @size = size
      @timeout = timeout
    end

    def perform(operations)
      # This fans out and starts off all the concurrent work, which starts and
      # immediately returns Concurrent::Promises::Future` objects for each operation.
      futures = operations.map do |operation|
        Concurrent::Promises.future do
          pool.with { |connection| operation.call(connection) }
        end
      end
      # At this point, all of the concurrent work has been started.

      # This converges back in, waiting on each concurrent future to finish, and fulfilling each
      # (non-concurrent) Promise.rb promise.
      operations.each_with_index.each do |operation, index|
        fulfill(operation, futures[index].value) # .value is a blocking call
      end
    end

  private

    def pool
      @pool ||= ConnectionPool.new(size: @size, timeout: @timeout) do
        HTTP.persistent(@host)
      end
    end
  end
end
