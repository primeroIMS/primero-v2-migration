# frozen_string_literal: true

# TODO: This was copied from the primero_v2 project.
# TODO: Need to modify this to be stand-alone script that can be run on a v1.7 or v1.6 system
# TODO: It should export config scripts compatible with v2
# TODO: Do not include users or roles for now

require 'fileutils'

# Exports the current state of the Primero configuration as Ruby scripts.
# TODO: The exporter does not account for Location, PrimeroModule, PrimeroProgram, SystemSettings
# TODO: Use PrimeroConfiguration. This will allow us to export past configuration states as Ruby.

def initialize(export_dir: 'seed-files', file: nil)
  @export_dir = export_dir
  FileUtils.mkdir_p(@export_dir)
  @file = file
  FileUtils.rm("#{@export_dir}/#{@file}") if @file && File.exist?("#{@export_dir}/#{@file}")
  @indent = 0
end

def i
  '  ' * @indent
end

def _i
  @indent += 1
end

def i_
  @indent -= 1
end

def file_for(config_name, config_objects = nil)
  return "#{@export_dir}/#{@file}" if @file

  if config_name == 'FormSection' && config_objects.present?
    config_dir = "#{@export_dir}/forms/#{config_objects.last['parent_form']}"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/#{config_objects.last['unique_id']}.rb"
  else
    config_dir = "#{@export_dir}/#{config_name.pluralize.underscore}"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/#{config_name.underscore}.rb"
  end
end

def forms_with_subforms
  grouped_forms = FormSection.all.group_by do |form|
    # form.is_nested ? form.subform_field&.form_section&.unique_id : form.unique_id
    form.unique_id
  end
  grouped_forms.map do |unique_id, form_and_subforms|
    [unique_id, form_and_subforms.sort_by { |form| form.is_nested? ? 0 : 1 }]
  end.to_h
end

def export_config_objects(config_name, objects)
  file_name = file_for(config_name, objects)
  File.open(file_name, 'a') do |f|
    objects.each do |config_object|
      f << config_to_ruby_string(config_name, config_object)
    end
  end
end

def config_to_ruby_string(config_name, config_hash)
  ruby_string = "#{i}#{config_name}.create_or_update!(\n"
  _i
  ruby_string += "#{i}#{value_to_ruby_string(config_hash)}"
  i_
  ruby_string + "\n#{i})\n\n"
end

# This is a long, recursive method.
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/AbcSize
def value_to_ruby_string(value)
  if value.is_a?(Hash)
    ruby_string = "{\n"
    _i
    ruby_string += i
    ruby_string += value.compact.map do |k, v|
      "#{key_to_ruby(k)}: #{value_to_ruby_string(v)}"
    end.join(",\n#{i}")
    i_
    ruby_string + "\n#{i}}"
  elsif value.is_a?(Array)
    ruby_string = '['
    if value.present?
      _i
      ruby_string += "\n#{i}"
      ruby_string += value.map { |v| value_to_ruby_string(v) }.join(",\n#{i}")
      i_
      ruby_string += "\n#{i}"
    end
    ruby_string + ']'
  else
    value.to_json
  end
end
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/AbcSize

def key_to_ruby(key)
  key.include?('-') ? "'#{key}'" : key
end

def unique_id(object)
  {
    unique_id: object.id
  }
end

def configuration_hash_agency(object)
  # TODO: handle logo
  object.attributes.except('id', 'base_language').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_lookup(object)
  object.attributes.except('id').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_report(object)
  # TODO: what to do with unique_id...
  object.attributes.except('id', 'exclude_empty_rows', 'base_language', 'primero_version').with_indifferent_access
end

def configuration_hash_user_group(object)
  object.attributes.except('id').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_primero_module(object)
  # TODO: fix FormSections / associated_form_ids
  # TODO: fix field maps
  object.attributes.except('id').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_primero_program(object)
  object.attributes.except('id').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_system_settings(object)
  # TODO remove default_locale & locales
  # TODO verify rest
  object.attributes.except('id', 'default_locale', 'locales').with_indifferent_access
end

def configuration_hash_contact_information(object)
  config_hash = object.attributes.except('id').with_indifferent_access
  config_hash[:name] ||= 'administrator'
  config_hash
end

def configuration_hash_form_section(object)
  # TODO: handle fields
  object.attributes.except('id', 'fields')
end

def export_forms
  forms_with_subforms.each do |_, form_with_subforms|
    forms_hash = form_with_subforms.map { |form| configuration_hash_form_section(form) }
    export_config_objects('FormSection', forms_hash)
  end
end

def config_objects(config_name)
  Object.const_get(config_name).all.map { |object| send("configuration_hash_#{config_name.underscore}", object) }
end

###################################
# Beginning of script
###################################
initialize

# TODO: Location, ExportConfiguration
# TODO: what about FormSection/field?  Handle that separately?
%w[Agency Lookup Report UserGroup PrimeroModule PrimeroProgram SystemSettings ContactInformation].each do |config_name|
  export_config_objects(config_name, config_objects(config_name))
end
export_forms


