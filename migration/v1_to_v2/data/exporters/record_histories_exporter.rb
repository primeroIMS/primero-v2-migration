# frozen_string_literal: true

require_relative('data_exporter.rb')

# Generates a v2.0+ compatible script to create record histories.
class RecordHistoriesExporter < DataExporter
  def export
    puts 'Exporting record histories...'
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
    'RecordHistory'
  end

  # rubocop:disable Style/StringLiterals
  def header
    [
      "# Automatically generated script to migrate record histories from v1.7 to v2.0+\n",
      "histories = [\n"
    ].join("\n").freeze
  end

  def ending(_object_name)
    [
      "]\n",
      "histories.each do |history|",
      "  puts \"Creating record history...\"",
      "  history.save!",
      "rescue ActiveRecord::RecordNotUnique",
      "  puts \"Skipping creation of history for \#{history.record_type} with id \#{history.record_id}. It already exists.\"",
      "rescue StandardError => e",
      "  puts \"Cannot create history for \#{history.record_type} with id \#{history.record_id} Error \#{e.message}\"",
      "  raise e",
      "end\n"
    ].join("\n").freeze
  end

  # rubocop:enable Style/StringLiterals

  def file_for(object_name, index)
    super(model_class(object_name), index)
  end

  def object_hashes(_, objects)
    objects.map do |object|
      next unless object.histories.present? && object.histories.is_a?(Array)

      object.histories.map do |history|
        history_hash = history.to_hash.except('unique_id', 'user_organization', 'prev_revision')
        history_hash['datetime'] = datetime_string(history_hash)
        history_hash['record_changes'] = history_hash.delete('changes')
        history_hash['record_id'] = uuid_format(object.id)
        history_hash['record_type'] = object.class.name
        history_hash
      end
    end.compact.flatten
  end

  def value_to_ruby_string(object_hash, _include_blank = false)
    super(object_hash, true)
  end

  def datetime_string(object_hash)
    return unless object_hash['datetime'].present?

    "DateTime.parse(\"#{object_hash['datetime'].strftime('%Y-%m-%dT%H:%M:%SZ')}\")"
  end
end
