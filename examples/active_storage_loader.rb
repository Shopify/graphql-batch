####
# This is a loader for has_one_attached and has_many_attached Active Storage attachments
# To load a variant for an attachment, 2 queries are required
# Using preloading via the includes method.
####

####
# The model with an attached image and many attached pictures
####

# class Event < ApplicationRecord
#   has_one_attached :image
#   has_many_attached :pictures
# end

####
# An example data type using the Loaders::ActiveStorageLoader
####

# class Types::EventType < Types::BaseObject
#   graphql_name 'Event'
#
#   field :id, ID, null: false
#   field :image, String, null: true
#   field :pictures, String, null: true
#
#   def image
#     Loaders::ActiveStorageLoader.for(:Event, :image).load(object.id).then do |image|
#       Rails.application.routes.url_helpers.url_for(
#         image.variant({ quality: 75 })
#       )
#     end
#   end
#
#   def pictures
#     Loaders::ActiveStorageLoader.for(:Event, :pictures, association_type: :has_many_attached).load(object.id).then do |pictures|
#       pictures.map do |picture|
#         Rails.application.routes.url_helpers.url_for(
#           picture.variant({ quality: 75 })
#         )
#       end
#     end
#   end
# end
module Loaders
  class ActiveStorageLoader < GraphQL::Batch::Loader
    attr_reader :record_type, :attachment_name, :association_type # should be has_one_attached or has_many_attached

    def initialize(record_type, attachment_name, association_type: :has_one_attached)
      super()
      @record_type = record_type
      @attachment_name = attachment_name
      @association_type = association_type
    end

    def perform(record_ids)
      # find records and fulfill promises
      attachments = ActiveStorage::Attachment.includes(:blob).where(
        record_type: record_type, record_id: record_ids, name: attachment_name
      )

      if @association_type == :has_one_attached
        attachments.each do |attachment|
          fulfill(attachment.record_id, attachment)
        end

        record_ids.each { |id| fulfill(id, nil) unless fulfilled?(id) }
      else
        record_ids.each do |record_id|
          fulfill(record_id, attachments.select { |attachment| attachment.record_id == record_id })
        end
      end
    end
  end
end
