class RecordLoader < GraphQL::Batch::Loader
  EMPTY_ARRAY = [].freeze

  def initialize(model, column: model.primary_key, where: nil, unique: true)
    @model = model
    @column = column
    @column_type = model.type_for_attribute(@column.to_s)
    @where = where
    @unique = unique
  end

  def load(key)
    super(@column_type.cast(key))
  end

  def perform(keys)
    if @unique
      query(keys).each do |record|
        fulfill(record.public_send(@column), record)
      end
      default = nil
    else
      query(keys).group_by(&@column).each do |key, result|
        fulfill(key, result)
      end
      default = EMPTY_ARRAY
    end
    keys.each { |key| fulfill(key, default) unless fulfilled?(key) }
  end

  private

  def query(keys)
    scope = @model
    scope = scope.where(@where) if @where
    scope.where(@column => keys)
  end
end
