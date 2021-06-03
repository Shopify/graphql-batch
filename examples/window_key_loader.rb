####
# This is a has_many loader which takes advantage of Postgres'
# windowing functionality to load the first N records for
# a given relationship.
####

####
# An example data type using the WindowKeyLoader
####

# class Types::CategoryType < Types::BaseObject
#   graphql_name 'Category'

#   field :id, ID, null: false
#   field :events, [Types::EventType], null: false do
#     argument :first, Int, required: false, default_value: 5
#   end

#   def events(first:)
#     WindowKeyLoader.for(
#       Event,
#       :category_id,
#       limit: first, order_col: :start_time, order_dir: :desc
#     ).load(object.id)
#   end
# end

####
# The SQL that is produced
####

# SELECT
#   "events".*
# FROM (
#   SELECT
#     "events".*,
#     row_number() OVER (PARTITION BY category_id ORDER BY start_time DESC) AS rank
#   FROM
#     "events"
#   WHERE
#     "events"."category_id" IN(1, 2, 3, 4, 5)) AS events
# WHERE (rank <= 5)

class WindowKeyLoader < GraphQL::Batch::Loader
  attr_reader :model, :foreign_key, :limit, :order_col, :order_dir

  def initialize(model, foreign_key, limit:, order_col:, order_dir: :asc)
    super()
    @model = model
    @foreign_key = foreign_key
    @limit = limit
    @order_col = order_col
    @order_dir = order_dir
  end

  def perform(foreign_ids)
    # build the sub-query, limiting results by foreign key at this point
    # we don't want to execute this query but get its SQL to be used later
    ranked_from =
      model.select(
        "*",
        "row_number() OVER (
          PARTITION BY #{foreign_key} ORDER BY #{order_col} #{order_dir}
        ) as rank"
      ).where(foreign_key => foreign_ids).to_sql

    # use the sub-query from above to query records which have a rank
    # value less than or equal to our limit
    records =
      model.from("(#{ranked_from}) as #{model.table_name}").where(
        "rank <= #{limit}"
      ).to_a

    # match records and fulfill promises
    foreign_ids.each do |foreign_id|
      matching_records =
        records.select { |r| foreign_id == r.send(foreign_key) }
      fulfill(foreign_id, matching_records)
    end
  end
end
