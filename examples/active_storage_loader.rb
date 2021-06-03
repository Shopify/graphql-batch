####
# This is a loader for has_one_attached Active Storage attachments
# To load a variant for an attachment, 2 queries are required
# Using preloading via the includes method.
####

####
# The model with an attached image
####

# class Event < ApplicationRecord
#   has_one_attached :image
# end

####
# An example data type using the AttachmentLoader
####

# class Types::EventType < Types::BaseObject
#   graphql_name 'Event'
#
#   field :id, ID, null: false
#   field :image, String, null: true
#
#   def image
#     AttachmentLoader.for(:Event, :image).load(object.id).then do |image|
#       Rails.application.routes.url_helpers.url_for(
#         image.variant({ quality: 75 })
#       )
#     end
#   end
# end

class ActiveStorageLoader < GraphQL::Batch::Loader
  attr_reader :record_type, :attachment_name

  def initialize(record_type, attachment_name)
    super()
    @record_type = record_type
    @attachment_name = attachment_name
  end

  def perform(record_ids)
    # find records and fulfill promises
    ActiveStorage::Attachment.includes(:blob).where(
      record_type: record_type, record_id: record_ids, name: attachment_name
    )
      .each { |record| fulfill(record.record_id, record) }

    # fulfill unfilfilled records
    record_ids.each { |id| fulfill(id, nil) unless fulfilled?(id) }
  end
end
