class FindQuery < GraphQL::Batch::Query
  attr_reader :model, :id

  def initialize(model:, id:, &block)
    @model = model
    @id = Integer(id)
    super(&block)
  end

  def group_key
    "#{super}:#{model.name}"
  end

  def self.execute(queries)
    model = queries.first.model
    ids = queries.map(&:id).uniq
    records = model.find(ids)
    records_by_id = records.each_with_object({}){ |r, h| h[r.id] = r }
    queries.each do |query|
      query.complete(records_by_id[query.id])
    end
  end
end

class AssociationQuery < GraphQL::Batch::Query
  attr_reader :owner, :association

  def initialize(owner:, association:, &block)
    @owner = owner
    @association = association
    super(&block)
  end

  def group_key
    "#{super}:#{owner.class}:#{association}"
  end

  def self.execute(queries)
    owner_class = queries.first.owner.class
    association = queries.first.association
    owners = queries.map(&:owner).uniq
    owner_class.preload_association(owners, association)
    queries.each do |query|
      query.complete(query.owner.public_send(association))
    end
  end
end
