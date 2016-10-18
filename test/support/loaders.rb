class RecordLoader < GraphQL::Batch::Loader
  def initialize(model)
    @model = model
  end

  def load(id)
    super(Integer(id))
  end

  def perform(ids)
    @model.find(ids).each { |record| fulfill(record.id, record) }
    ids.each { |id| fulfill(id, nil) unless fulfilled?(id) }
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

class CounterLoader < GraphQL::Batch::Loader
  def initialize(hash)
    @hash = hash
  end

  def load(key=Object.new)
    super(key)
  end

  def perform(keys)
    keys.each { |key| fulfill(key, @hash[:counter][0]) }
  end
end

class NilLoader < GraphQL::Batch::Loader
  def self.load
    self.for.load(nil)
  end

  def perform(nils)
    nils.each { |key| fulfill(nil, nil) }
  end
end
