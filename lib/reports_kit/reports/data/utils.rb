module ReportsKit
  module Reports
    module Data
      class Utils
        def self.format_configuration_time(time)
          time.strftime('%d.%m.%Y')
        end

        def self.format_csv_time(time)
          time.strftime('%Y-%m-%d')
        end

        def self.format_display_time(time)
          time.strftime('%d.%m.%Y')
        end

        def self.format_date_range(string)
          start_at, end_at = parse_date_range(string, type: Array)
          [format_display_time(start_at), FilterTypes::Datetime::SEPARATOR, format_display_time(end_at)].join(' ')
        end

        def self.format_time_value(value)
          time = RelativeTime.parse(value, prevent_exceptions: true)
          return value unless time
          Utils.format_configuration_time(time)
        end

        def self.format_number(number)
          number_i = number.to_i
          return number_i if number == number_i
          number.round(Generate::ROUND_PRECISION)
        end

        def self.quote_column_name(string)
          ActiveRecord::Base.connection.quote_column_name(string)
        end

        def self.parse_date_string(string)
          Date.parse(string)
        rescue ArgumentError
          RelativeTime.parse(string)
        end

        def self.parse_date_range(string, type: nil)
          return if string.blank?
          start_string, end_string = string.split(FilterTypes::Datetime::SEPARATOR)
          start_at = parse_date_string(start_string)
          end_at = parse_date_string(end_string)
          if type == Array
            [start_at, end_at]
          else
            (start_at..end_at)
          end
        end

        def self.populate_sparse_hash(hash, dimension:)
          keys = hash.keys
          is_nested = dimension.series.has_two_dimensions?
          if is_nested
            keys_values = arrays_values_to_nested_hash(hash)
            keys = keys_values.keys
          else
            keys_values = hash
          end

          first_key = dimension.first_key || keys.first
          return hash unless first_key.is_a?(Time) || first_key.is_a?(Date)
          keys_values = keys_values.map do |key, value|
            key = key.to_date if key.is_a?(Time)
            [key, value]
          end.to_h

          keys = populate_sparse_keys(keys, dimension: dimension)
          populated_keys_values = {}
          default_value = is_nested ? {} : 0
          keys.each do |key|
            populated_keys_values[key] = keys_values[key] || default_value
          end
          return nested_hash_to_arrays_values(populated_keys_values) if is_nested
          populated_keys_values
        end

        def self.populate_sparse_keys(keys, dimension:)
          first_key = dimension.first_key || keys.first
          return keys unless first_key.is_a?(Time) || first_key.is_a?(Date)
          first_key = first_key.to_date
          granularity = dimension.granularity

          keys = keys.sort
          last_key = (dimension.last_key || keys.last).to_date
          if granularity == 'week'
            first_key = first_key.beginning_of_week(ReportsKit.configuration.first_day_of_week)
            last_key = last_key.beginning_of_week(ReportsKit.configuration.first_day_of_week)
          elsif granularity == 'month'
            first_key = first_key.beginning_of_month
            last_key = last_key.beginning_of_month
          end

          date = first_key
          populated_keys = []
          interval = case granularity
                     when 'day' then 1.day
                     when 'month' then 1.month
                     else 1.week
                     end
          loop do
            populated_keys << date
            break if date >= last_key
            date += interval
          end
          populated_keys
        end

        def self.arrays_values_to_nested_hash(arrays_values)
          nested_hash = {}
          arrays_values.each do |(key1, key2), value|
            nested_hash[key1] ||= {}
            nested_hash[key1][key2] ||= value
          end
          nested_hash
        end

        def self.nested_hash_to_arrays_values(nested_hash)
          arrays_values = {}
          nested_hash.each do |key1, key2s_values|
            if key2s_values.blank?
              arrays_values[[key1, nil]] = 0
              next
            end
            key2s_values.each do |key2, value|
              arrays_values[[key1, key2]] = value
            end
          end
          arrays_values
        end

        def self.dimension_to_dimension_ids_dimension_instances(dimension, dimension_ids)
          return nil unless dimension.instance_class
          primary_key = dimension.instance_class.primary_key
          dimension_instances = dimension.instance_class.where(primary_key => dimension_ids.uniq)
          dimension_ids_dimension_instances = dimension_instances.map do |dimension_instance|
            [dimension_instance.send(primary_key), dimension_instance]
          end
          Hash[dimension_ids_dimension_instances]
        end

        def self.dimension_key_to_entity(dimension_key, dimension, dimension_ids_dimension_instances)
          instance = dimension_ids_dimension_instances ? dimension_ids_dimension_instances[dimension_key] : dimension_key
          label = dimension_key_to_label(dimension_key, dimension, dimension_ids_dimension_instances)
          Entity.new(dimension_key, label, instance)
        end

        def self.dimension_key_to_label(dimension_instance, dimension, ids_dimension_instances)
          label = dimension.key_to_label(dimension_instance)
          return label if label
          return dimension_instance.to_s if dimension.configured_by_column? && dimension.column_type == :integer
          case dimension_instance
          when Time, Date
            Utils.format_display_time(dimension_instance)
          when Fixnum
            raise ArgumentError.new("ids_dimension_instances must be present for Dimension with identifier: #{dimension_instance}") unless ids_dimension_instances
            instance = ids_dimension_instances[dimension_instance.to_i]
            return unless instance
            instance.to_s
          else
            dimension_instance.to_s.gsub(/\.0$/, '')
          end
        end

        def self.raw_value_to_value(raw_value, value_format_method)
          formatted_value = format_number(raw_value)
          formatted_value = value_format_method.call(raw_value) if value_format_method
          Value.new(raw_value, formatted_value)
        end
      end
    end
  end
end
