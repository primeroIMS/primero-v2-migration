# frozen_string_literal: true

require 'fileutils'

# Exports v1 Primero record data as v2 compatible JSON files.
class RecordDataExporter
  HEADER = [
    "# Automatically generated script to migrate record data from v1.7 to v2.0+\n",
    "records = [\n"
  ].join("\n").freeze

  ENDING = [
    "]\n",
    'records.each do |record|',
    "  puts \"Creating record \#{record.id}\"",
    '  record.save!',
    'rescue ActiveRecord::RecordNotUnique',
    "  puts \"Skipping. Record \#{record.id} already exists!\"",
    'rescue StandardError => e',
    "  puts \"Cannot create \#{record.id}. Error \#{e.message}\"",
    '  raise e',
    "end\n"
  ].join("\n").freeze

  def initialize(export_dir: 'record-data-files', batch_size: 500)
    @export_dir = export_dir
    @batch_size = batch_size
    FileUtils.mkdir_p(@export_dir)
    @indent = 1
  end

  def export
    %w[Case Incident TracingRequest].each do |record_type|
      export_records(record_type)
    end
  end

  private

  def i
    '  ' * @indent
  end

  def _i
    @indent += 1
  end

  def i_
    @indent -= 1
  end

  def model_class(record_type)
    record_type == 'Case' ? 'Child' : record_type
  end

  def file_for(record_type, index)
    config_dir = "#{@export_dir}/#{record_type.pluralize.underscore}"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/#{record_type.underscore}#{index}.rb"
  end

  def export_record_objects(record_type, objects, index)
    return if objects.blank?

    File.open(file_for(record_type, index), 'a') do |file|
      file.write(HEADER)
      objects.each { |object| file.write(config_to_ruby_string(object, record_type)) }
      file.write(ENDING)
    end
  end

  def config_to_ruby_string(object_hash, record_type)
    ruby_string = "#{i}#{model_class(record_type)}.new(\n"
    _i
    ruby_string += "#{i}#{value_to_ruby_string(object_hash)}"
    i_
    ruby_string + "),\n"
  end

  def array_value_to_ruby_string(value)
    return '[]' if value.blank?

    ruby_string = ''
    if value.first.is_a?(Range)
      ruby_string = value.map { |v| value_to_ruby_string(v) }.to_s
    else
      ruby_string = '['
      _i
      ruby_string += "\n#{i}"
      ruby_string += value.map { |v| value_to_ruby_string(v) }.join(",\n#{i}")
      i_
      ruby_string += "\n#{i}"
      ruby_string += ']'
    end
    ruby_string
  end

  # This is a long, recursive method.
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def value_to_ruby_string(value)
    if value.is_a?(Hash)
      ruby_string = "{\n"
      _i
      ruby_string += i
      # TODO: was using .compact instead of .reject but it was throwing away false values.  We want to keep those
      ruby_string += value.reject { |_, v| v.nil? || v == [] }.map do |k, v|
        "#{key_to_ruby(k)}: #{value_to_ruby_string(v)}"
      end.join(",\n#{i}")
      i_
      ruby_string + "\n#{i}}"
    elsif value.is_a?(Array)
      array_value_to_ruby_string(value)
    elsif value.is_a?(Range)
      value
    elsif value.is_a?(String) && value.include?('.parse(')
      value
    else
      value.to_json
    end
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  def key_to_ruby(key)
    key.is_a?(Integer) || key.include?('-') ? "'#{key}'" : key
  end

  def migrate_notes(notes)
    notes.each do |note|
      note['note_date'] = note.delete('notes_date')
      note['note_text'] = note.delete('field_notes_subform_fields')
    end
  end

  def record_hash_case(record_hash)
    keys = record_hash.keys
    record_hash['notes_section'] = migrate_notes(record_hash['notes_section']) if record_hash['notes_section'].present?
    record_hash['unhcr_export_opt_in'] = !record_hash.delete('unhcr_export_opt_out') if keys.include?('unhcr_export_opt_out')
    record_hash['assessment_approved'] = record_hash.delete('bia_approved') if keys.include?('bia_approved')
    record_hash['assessment_approved_date'] = record_hash.delete('bia_approved_date') if keys.include?('bia_approved_date')
    record_hash['assessment_approved_comments'] = record_hash.delete('bia_approved_comments') if keys.include?('bia_approved_comments')
    record_hash['approval_status_assessment'] = record_hash.delete('approval_status_bia') if keys.include?('approval_status_bia')
    record_hash['status'] = record_hash.delete('child_status')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    record_hash.except('other_documents', 'incident_details', 'transitions', 'flags', 'approval_subforms')
  end

  def record_hash_incident(record_hash)
    keys = record_hash.keys
    record_hash['short_id'] = record_hash.delete('cp_short_id') if keys.include?('cp_short_id')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    record_hash
  end

  def record_hash_tracing_request(record_hash)
    record_hash['status'] = record_hash.delete('inquiry_status')
    record_hash
  end

  def flag_date_fields(object, record_hash)
    record_hash.each do |key, value|
      next unless object[key].is_a?(DateTime) || object[key].is_a?(Date) || (value.is_a?(Array) && value.first&.is_a?(Hash))

      if value.is_a?(Array)
        record_hash[key] = value.map.with_index { |v, index| flag_date_fields(object[key][index], v) }
        next
      end

      record_hash[key] = object[key].is_a?(DateTime) ? "DateTime.parse(\"#{value}\")" : "Date.parse(\"#{value}\")"
    end
    record_hash
  end

  def parse_object(object)
    # TODO: was using .compact instead of .reject but it was throwing away false values.  We want to keep those
    record_hash = JSON.parse(object.to_json)&.reject { |_, v| v.nil? || v == [] }&.except('histories', '_attachments',
                                                                                          'other_documents', 'flags',
                                                                                          '_id', '_rev',
                                                                                          'couchrest-type')
    flag_date_fields(object, record_hash)
  end

  def uuid_format(old_id)
    [old_id[0..7], old_id[8..11], old_id[12..15], old_id[16..19], old_id[20..31]].join('-')
  end

  def record_data_hash(record_type, object)
    record_hash = {}
    record_hash['id'] = uuid_format(object.id)
    record_hash['data'] = send("record_hash_#{record_type.underscore}", parse_object(object))
    record_hash
  end

  def record_objects(record_type, objects)
    objects.map { |object| record_data_hash(record_type, object) }
  end

  def export_records(record_type)
    puts "Exporting #{record_type.pluralize}"
    index = 0
    Object.const_get(model_class(record_type)).each_slice(@batch_size) do |objects|
      export_record_objects(record_type, record_objects(record_type, objects), index)
      index += 1
    end
  end
end
