module ReportsKit
  module Reports
    module Data
      class Utils
        def self.format_time(time)
          time.strftime('%b %-d, \'%y')
        end

        def self.populate_sparse_values(dimension_keys_values, use_first_value_key: false)
          return dimension_keys_values if dimension_keys_values.blank?
          first_key = dimension_keys_values.first.first
          return dimension_keys_values unless first_key.is_a?(Time)

          beginning_of_current_week = Time.now.utc.beginning_of_week(ReportsKit.configuration.first_day_of_week)
          last_key = dimension_keys_values.to_a.last.first
          last_key = [beginning_of_current_week, last_key].compact.max

          time = first_key
          full_dimension_instances_values = []
          if use_first_value_key
            first_value_key = dimension_keys_values.first.last.keys.first
            blank_value = { first_value_key => 0 }
          else
            blank_value = 0
          end
          loop do
            full_dimension_instances_values << [time, dimension_keys_values[time] || blank_value]
            break if time >= last_key
            time += 1.week
          end
          Hash[full_dimension_instances_values]
        end

        def self.populate_sparse_keys(keys)
          return keys if keys.blank?
          first_key = keys.first
          return keys unless first_key.is_a?(Time)
          keys = keys.sort
          beginning_of_current_week = Time.now.utc.beginning_of_week(ReportsKit.configuration.first_day_of_week)
          last_key = keys.last
          last_key = [beginning_of_current_week, last_key].compact.max

          time = first_key
          populated_keys = []
          loop do
            populated_keys << time
            break if time >= last_key
            time += 1.week
          end
          populated_keys
        end

        def self.dimension_to_dimension_ids_dimension_instances(dimension, dimension_ids)
          return nil unless dimension.instance_class
          dimension_instances = dimension.instance_class.where(id: dimension_ids)
          dimension_ids_dimension_instances = dimension_instances.map do |dimension_instance|
            [dimension_instance.id, dimension_instance]
          end
          Hash[dimension_ids_dimension_instances]
        end

        def self.dimension_key_to_label(dimension_instance, ids_dimension_instances)
          case dimension_instance
          when Time
            Utils.format_time(dimension_instance)
          when Fixnum
            raise ArgumentError.new("ids_dimension_instances must be present for Dimension with identifier: #{dimension_instance}") unless ids_dimension_instances
            instance = ids_dimension_instances[dimension_instance.to_i]
            raise ArgumentError.new("instance could not be found for Dimension with identifier: #{dimension_instance}") unless instance
            instance.to_s
          else
            dimension_instance.to_s.gsub(/\.0$/, '')
          end
        end
      end
    end
  end
end