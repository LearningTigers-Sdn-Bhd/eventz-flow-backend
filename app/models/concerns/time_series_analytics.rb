# Provides time-series analytics grouping for models.
# Uses the groupdate gem for hourly, daily, weekly, and monthly aggregations.
module TimeSeriesAnalytics
  extend ActiveSupport::Concern

  VALID_GROUP_BY = %w[hour day week month].freeze

  class_methods do
    # Returns time-series data grouped by the specified period.
    #
    # @param timestamp_column [Symbol] The column to group by (e.g., :created_at)
    # @param range [Range] The date/time range to query
    # @param group_by [String] One of: 'hour', 'day', 'week', 'month'
    # @return [Array<Hash>] Array of { period:, value: } hashes
    def time_series_count(timestamp_column, range:, group_by:)
      validate_group_by!(group_by)

      grouped_data = where(timestamp_column => range)
                       .send(grouping_method(group_by), timestamp_column)
                       .count

      format_time_series(grouped_data, group_by)
    end

    # Returns time-series sum for a given column.
    #
    # @param timestamp_column [Symbol] The column to group by
    # @param sum_column [String] The column/expression to sum
    # @param range [Range] The date/time range to query
    # @param group_by [String] One of: 'hour', 'day', 'week', 'month'
    # @return [Array<Hash>] Array of { period:, value: } hashes
    def time_series_sum(timestamp_column, sum_column, range:, group_by:)
      validate_group_by!(group_by)

      grouped_data = where(timestamp_column => range)
                       .send(grouping_method(group_by), timestamp_column)
                       .sum(sum_column)

      format_time_series(grouped_data, group_by)
    end

    private

    def validate_group_by!(group_by)
      return if VALID_GROUP_BY.include?(group_by.to_s)

      raise ArgumentError, "Invalid group_by: #{group_by}. Must be one of: #{VALID_GROUP_BY.join(', ')}"
    end

    def grouping_method(group_by)
      case group_by.to_s
      when 'hour'  then :group_by_hour
      when 'day'   then :group_by_day
      when 'week'  then :group_by_week
      when 'month' then :group_by_month
      end
    end

    def format_time_series(grouped_data, group_by)
      grouped_data.map do |period, value|
        {
          period: format_period(period, group_by),
          value: value.to_i
        }
      end
    end

    def format_period(period, group_by)
      case group_by.to_s
      when 'hour'  then period.strftime('%Y-%m-%d %H:00')
      when 'day'   then period.strftime('%Y-%m-%d')
      when 'week'  then period.strftime('%Y-%m-%d')
      when 'month' then period.strftime('%Y-%m')
      end
    end
  end
end
