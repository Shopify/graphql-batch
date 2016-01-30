class RecordLoader < GraphQL::Batch::Loader
  def initialize(model)
    @model = model
  end

  def load(id)
    super(Integer(id))
  end

  def perform(ids)
    @model.find(ids).each { |record| fulfill(record.id, record) }
  end
end

class AssociationLoader < GraphQL::Batch::Loader
  def initialize(model, association)
    @model = model
    @association = association
  end

  def perform(owners)
    @model.preload_association(owners, @association)
    owners.each { |owner| fulfill(owner, owner.public_send(@association)) }
  end
end
