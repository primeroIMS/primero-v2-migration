# frozen_string_literal: true

require_relative('data_exporter.rb')

# Generates a v2.0+ compatible script to create flags.
class FlagsExporter < DataExporter
  DATE_FIELDS = %w[date created_at unflagged_date].freeze

  def export
    puts 'Exporting flags...'
    super
  end

  private

  def data_object_names
    %w[Child Incident TracingRequest]
  end

  def object_query(object_name)
    Object.const_get(object_name)
  end

  def model_class(_object_name)
    'Flag'
  end

  def excluded_attributes
    ['id']
  end

  def file_for(object_name, index)
    super(model_class(object_name), index)
  end

  def object_hashes(_, objects)
    objects.map do |object|
      next unless object.flags.present? && object.flags.is_a?(Array)

      object.flags.map do |flag|
        flag_hash = flag.to_hash.except('id', 'unique_id')
        flag_hash['record_id'] = uuid_format(object.id)
        flag_hash['record_type'] = object.class.name
        append_date_fields(flag_hash)
        flag_hash
      end
    end.compact.flatten
  end

  def append_date_fields(flag_hash)
    DATE_FIELDS.each do |field|
      value = flag_hash[field]
      next unless value.present?

      if field == 'created_at'
        flag_hash[field] = "DateTime.parse(\"#{value.strftime('%Y-%m-%dT%H:%M:%SZ')}\")"
        next
      end

      flag_hash[field] = "Date.parse(\"#{value.strftime('%Y-%m-%d')}\")"
    end
  end
end
