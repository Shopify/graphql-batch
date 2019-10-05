# A sample HTTP loader using:
#
# 1. https://github.com/httprb/http
# 2. https://github.com/mperham/connection_pool
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

module Loaders
  class HTTPLoader < GraphQL::Batch::Loader
    def initialize(host:, size: 4, timeout: 4)
      @host = host
      @size = size
      @timeout = timeout
    end

    def perform(operations)
      threads = operations.map do |operation|
        Thread.new do
          pool.with { |connection| operation.call(connection) }
        end
      end
      operations.each_with_index.each do |operation, index|
        fulfill(operation, threads[index].value)
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
