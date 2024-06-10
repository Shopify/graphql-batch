####
# This is a loader for Active Storage attachments,
# a little bit more complex than the `active_storage_loader.rb` example
# because it supports STI (Single Table Inheritance) models where the
# `has_one_attached` or `has_many_attached` is defined on any of the ancestor classes of the model.

####
# The model with an attached image and many attached pictures:
####

# class Event < ApplicationRecord
#   has_one_attached :image
#   has_many_attached :pictures
# end

####
# An example data type using the AttachmentLoader:
####

# class Types::EventType < Types::BaseObject
#   graphql_name 'Event'
#
#   field :id, ID, null: false
#   field :image, String, null: true
#   field :pictures, String, null: true
#
#   def image
#     AttachmentLoader.for(:Event, :image).load(object.id).then do |image|
#       Rails.application.routes.url_helpers.url_for(
#         image.variant({ quality: 75 })
#       )
#     end
#   end
#
#   def pictures
#     AttachmentLoader.for(:Event, :pictures, association_type: :has_many_attached).load(object.id).then do |pictures|
#       pictures.map do |picture|
#         Rails.application.routes.url_helpers.url_for(
#           picture.variant({ quality: 75 })
#         )
#       end
#     end
#   end
# end

class ActiveStorageLoader < GraphQL::Batch::Loader
  attr_reader :record_type, :attachment_name, :association_type

  def initialize(record_type, attachment_name, association_type: :has_one_attached)
    super()
    @record_type = record_type
    @attachment_name = attachment_name
    @association_type = association_type
  end

  def perform(record_ids)
    attachments = ActiveStorage::Attachment.includes(:blob, :record).where(
      record_type: ancestors_record_types, record_id: record_ids, name: attachment_name
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

  private

  def ancestors_record_types
    # Get all ancestor classes of record_type that are descendants of ActiveRecord::Base
    # This is necessary because in a Single Table Inheritance (STI) setup,
    # the `has_one_attached` or `has_many_attached`
    # could be defined on any of the ancestor classes of the model, not just the model itself,
    # which determines whether the `record_type` string is stored as the model's class name
    # or the ancestor's class name.
    # So we for any of the ancestor classes to ensure we don't miss the attachment
    # we are looking for:

    @record_type.to_s.constantize.ancestors.select do |ancestor|
      ancestor < ActiveRecord::Base
    end.map(&:to_s)
  end
end
