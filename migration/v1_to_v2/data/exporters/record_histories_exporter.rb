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

  def excluded_attributes
    ['id']
  end

  def file_for(object_name, index)
    super(model_class(object_name), index)
  end

  def object_hashes(_, objects)
    objects.map do |object|
      next unless object.histories.present? && object.histories.is_a?(Array)

      object.histories.reverse.map do |history|
        history_hash = history.to_hash.except('unique_id', 'user_organization', 'prev_revision')
        history_hash['datetime'] = datetime_string(history_hash)
        history_hash['record_changes'] = format_changes(history_hash.delete('changes'))
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

  def format_changes(changes)
    return if changes.nil?
    return changes unless changes.is_a?(Hash)

    changes.keys.inject({}) do |acc, elem|
      change = changes[elem]

      next(acc.merge(elem => change)) if change.key?('to') || change.key?('from')

      acc.merge(elem => format_subform_change(change))
    end
  end

  def format_subform_change(change)
    subform_ids = change.keys

    subform_ids.each_with_object('to' => nil, 'from' => nil) do |elem, acc|
      next if change[elem].blank?

      subform_fields = change[elem]&.keys
      subform_change = change[elem]

      subform_from = build_subform(subform_change, subform_fields, 'from')

      subform_to = build_subform(subform_change, subform_fields, 'to')

      acc['from'] = change_value(acc['from'], subform_from)
      acc['to'] = change_value(acc['to'], subform_to)

      acc
    end
  end

  def build_subform(subform_change, subform_fields, diff_field)
    subform_fields.inject({}) { |acc, elem| acc.merge(elem => subform_change[elem][diff_field]) }
  end

  def change_value(current_diff, subform)
    return current_diff.push(subform) if current_diff.present?

    subform.reject { |_, v| v.nil? }.present? ? [subform] : nil
  end
end
