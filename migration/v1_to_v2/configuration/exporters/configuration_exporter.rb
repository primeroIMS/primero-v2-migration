# frozen_string_literal: true

require 'fileutils'

# Exports the current v1.7 or v1.6 state of the Primero configuration as v2 compatible Ruby scripts.
class ConfigurationExporter
  def initialize(export_dir: 'seed-files', batch_size: 250)
    @export_dir = export_dir
    @batch_size = batch_size
    FileUtils.mkdir_p(@export_dir)
    @indent = 0
  end

  def export
    config_object_names.each do |config_name|
      puts "Exporting #{config_name.pluralize}"
      export_config_objects(config_name, config_objects(config_name))
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

  def file_for(opts = {})
    config_dir = "#{@export_dir}/#{opts[:config_name].pluralize.underscore}"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/#{opts[:config_name].underscore}.rb"
  end

  # These forms are now hard coded in v2 and the form configs are no longer needed
  def retired_forms
    %w[approvals approval_subforms referral_transfer record_owner incident_record_owner cp_incident_record_owner
       transitions reopened_logs]
  end

  def renamed_fields
    {
      'notes_date' => 'note_date',
      'field_notes_subform_fields' => 'note_text',
      'upload_other_document' => 'other_documents',
      'child_status' => 'status',
      'inquiry_status' => 'status',
      'unhcr_export_opt_out' => 'unhcr_export_opt_in',
      'approval_status_bia' => 'approval_status_assessment',
      'cp_short_id' => 'short_id',
      'current_photo_key' => 'photos',
      'cp_incident_date' => 'incident_date',
      'cp_incident_location' => 'incident_location',
      'cp_incident_sexual_violence_type' => 'cp_incident_violence_type',
      'gbv_sexual_violence_type' => 'cp_incident_violence_type',
      'reassigned_tranferred_on' => 'reassigned_transferred_on'
    }.freeze
  end

  def replace_renamed_field_names(field_names)
    return field_names unless field_names.is_a?(Array)

    new_field_names = field_names - renamed_fields.keys
    renamed_fields.each do |key, value|
      new_field_names << value if field_names.include?(key)
    end
    new_field_names
  end

  def forms_with_subforms(opts = {})
    return @forms_with_subforms if @forms_with_subforms.present?

    fs = FormSection.all.reject{ |form| form.is_nested || (opts[:visible_only] && !form.visible) }.group_by(&:unique_id)
    grouped_forms = {}
    fs.each do |k, v|
      # Hide the Incident Details form
      v.first.visible = false if k == 'incident_details_container'

      grouped_forms[k] = v + FormSection.get_subforms(v) unless retired_forms.include?(v.first.unique_id)
    end
    @forms_with_subforms = grouped_forms.map do |unique_id, form_and_subforms|
      [unique_id, form_and_subforms.sort_by { |form| form.is_nested? ? 0 : 1 }]
    end.to_h
    @forms_with_subforms
  end

  def export_config_objects(config_name, objects)
    file_name = file_for(config_name: config_name, config_objects: objects)
    File.open(file_name, 'a') do |f|
      objects.each do |config_object|
        f << config_to_ruby_string(config_name, config_object)
      end
    end
  end

  def config_to_ruby_string(config_name, config_hash)
    create_string = config_hash['unique_id'].present? ? "create_or_update" : "create"
    ruby_string = "#{i}#{config_name}.#{create_string}!(\n"
    _i
    ruby_string += "#{i}#{value_to_ruby_string(config_hash)}"
    i_
    ruby_string + "\n#{i})\n\n"
  end

  def migrate_config_fields_translations(object, parent_lang='')
    translation_fields = [
      'description_',
      'display_name_',
      'guiding_questions_',
      'help_text_',
      'name_',
      'tick_box_label_',
      'upload_document_help_text_',
      'tally_',
    ]
    translation_array_fields = [
      'option_strings_text_',
      'lookup_values_'
    ]


    config_object = Marshal.load(Marshal.dump(object))
    if object.kind_of?(Array) && parent_lang.empty?
      return config_object.map { |item|
        migrate_config_fields_translations(item)
      }
    end

    config_object.keys.each do |key|
      m = key.match(/^(#{(translation_fields).join('|')})([a-z]{2}|[a-z]{2}[_-]{1}[A-Z]{2})/)
      ma = key.match(/^(#{(translation_array_fields).join('|')})([a-z]{2}|[a-z]{2}[_-]{1}[A-Z]{2})/)

      if m
        value = config_object.delete(key)
        next unless value.present?

        new_key = m[1].to_s.concat('i18n')
        config_object[new_key] = {} unless config_object.key?(new_key)
        lang = m[2].gsub('_', '-')
        config_object[new_key][lang] = value
      elsif key == 'display_text'
        value = config_object.delete(key)
        config_object[key] = { parent_lang => value }
      elsif config_object[key].kind_of?(Array) && config_object[key].any? && config_object[key].first.kind_of?(Hash)
        config_object_values = config_object.delete(key)
        if ma
          lang = ma[2].gsub('_', '-')
          values = config_object_values.map { |obj| migrate_config_fields_translations(obj, lang) }
          next unless values.present?

          new_key = ma[1].to_s.concat('i18n')
          if config_object.key?(new_key)
            hsh = Hash[values.map {|h| [h[:id], h[:display_text]]}]
            config_object[new_key] = config_object[new_key].map { |h| h[:display_text] = h[:display_text].merge(hsh[h[:id]]); h }
          else
            config_object[new_key] = values
          end
        else
          values = config_object_values.map { |obj| migrate_config_fields_translations(obj) }
          next unless values.present?
          config_object[key] = values
        end
      end
    end

    config_object
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
    elsif value.is_a?(String) && (value.include?('.where(') || value.include?('.find_by('))
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

  def unique_id(object)
    {
      unique_id: object.id
    }
  end

  def config_objects(config_name)
    Object.const_get(config_name).all.map { |object| send("configuration_hash_#{config_name.underscore}", object) }
  end

  def system_settings
    @system_settings ||= SystemSettings.current
    @system_settings
  end

  def config_object_names
    []
  end
end
