# frozen_string_literal: true

require 'fileutils'

# Exports v1 Primero record data as v2 compatible ruby files.
class DataExporter
  def initialize(export_dir: 'record-data-files', batch_size: 250)
    @export_dir = export_dir
    @batch_size = batch_size
    FileUtils.mkdir_p(@export_dir)
    @indent = 1
  end

  def export
    data_object_names.each { |object_name| export_data_objects(object_name) }
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

  def file_for(object_name, index)
    config_dir = "#{@export_dir}/#{object_name.pluralize.underscore}"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/#{object_name.underscore}#{index}.rb"
  end

  def header
    [
      "# Automatically generated script to migrate record data from v1.7 to v2.0+\n",
      "records = [\n"
    ].join("\n")
  end

  def ending(object_name)
    [
      "]\n",
      'records.each do |record|',
      "  puts \"Creating #{object_name} \#{record.id}\"",
      '  record.save!',
      'rescue ActiveRecord::RecordNotUnique',
      "  puts \"Skipping. #{object_name} \#{record.id} already exists!\"",
      'rescue StandardError => e',
      "  puts \"Cannot create \#{record.id}. Error \#{e.message}\"",
      '  raise e',
      "end\n"
    ].join("\n").freeze
  end

  def export_object_batch(object_name, objects, index)
    return if objects.blank?

    File.open(file_for(object_name, index), 'a') do |file|
      file.write(header)
      objects.each { |object| file.write(config_to_ruby_string(object, object_name)) }
      file.write(ending(object_name))
    end
  end

  def new_string(record_type)
    "#{model_class(record_type)}.new"
  end

  def config_to_ruby_string(object_hash, record_type)
    ruby_string = "#{i}#{new_string(record_type)}(\n"
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

  def flag_date_fields(object, data_hash)
    data_hash.each do |key, value|
      next unless object[key].is_a?(DateTime) || object[key].is_a?(Date) || (value.is_a?(Array) && value.first&.is_a?(Hash))

      if value.is_a?(Array)
        data_hash[key] = value.map.with_index { |v, index| flag_date_fields(object[key][index], v) }
        next
      end

      data_hash[key] = object[key].is_a?(DateTime) ? "DateTime.parse(\"#{value}\")" : "Date.parse(\"#{value}\")"
    end
    data_hash
  end

  def parse_object(object)
    # TODO: was using .compact instead of .reject but it was throwing away false values.  We want to keep those
    data_hash = JSON.parse(object.to_json)&.reject { |_, v| v.nil? || v == [] }&.except('histories', '_attachments',
                                                                                          'other_documents', 'flags',
                                                                                          '_id', '_rev',
                                                                                          'couchrest-type')
    flag_date_fields(object, data_hash)
  end

  def uuid_format(old_id)
    return nil if old_id.blank?

    [old_id[0..7], old_id[8..11], old_id[12..15], old_id[16..19], old_id[20..31]].join('-')
  end

  def data_hash_incident(data_hash)
    keys = data_hash.keys
    data_hash['short_id'] = data_hash.delete('cp_short_id') if keys.include?('cp_short_id')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    data_hash
  end

  def object_data_hash(object_name, object)
    data_hash = {}
    data_hash['id'] = uuid_format(object.id)
    data_hash['data'] = send("data_hash_#{object_name.underscore}", parse_object(object))
    data_hash
  end

  def object_hashes(object_name, objects)
    objects.map { |object| object_data_hash(object_name, object) }
  end

  def object_query(object_name)
    Object.const_get(model_class(object_name))
  end

  def export_data_objects(object_name)
    puts "Exporting #{object_name.pluralize}"
    index = 0
    object_query(object_name).each_slice(@batch_size) do |objects|
      export_object_batch(object_name, object_hashes(object_name, objects), index)
      index += 1
    end
  end

  def data_object_names
    []
  end
end
