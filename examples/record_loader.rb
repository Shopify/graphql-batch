class RecordLoader < GraphQL::Batch::Loader
  def initialize(model, column: model.primary_key, where: nil, unique: true)
    @model = model
    @column = column.to_s
    @column_type = model.type_for_attribute(@column)
    @where = where
    @unique = unique
  end

  def load(key)
    super(@column_type.cast(key))
  end

  def perform(keys)
    if @unique
      default = nil
      query(keys).each { |record| fulfill(record.public_send(@column), record) }
    else
      default = []
      query(keys).group_by { |record| record.public_send(@column) }.each do |key, records|
        fulfill(key, records)
      end
    end
    keys.each { |key| fulfill(key, default.dup) unless fulfilled?(key) }
  end

  private

  def query(keys)
    scope = @model
    scope = scope.where(@where) if @where
    scope.where(@column => keys)
  end
end
