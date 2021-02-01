# frozen_string_literal: true

# Exports the current state of the Primero configuration as v2 compatible Ruby scripts.
# This was copied from the primero_v2 project: app/models/exporters/ruby_config_exporter.rb.
# It was modified to be stand-alone script that can be run on a v1.7 or v1.6 system.
# TODO: The exporter does not account for Location, ExportConfiguration, User, Role

require 'fileutils'

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

def array_value_to_ruby_string(value)
  return '[]' if value.blank?

  ruby_string = ''
  if value.first.is_a?(Range)
    ruby_string = "#{ value.map { |v| value_to_ruby_string(v) } }"
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
    ruby_string += value.compact.map do |k, v|
      "#{key_to_ruby(k)}: #{value_to_ruby_string(v)}"
    end.join(",\n#{i}")
    i_
    ruby_string + "\n#{i}}"
  elsif value.is_a?(Array)
    array_value_to_ruby_string(value)
  elsif value.is_a?(Range)
    value
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

def generate_report_id(name)
  code = UUIDTools::UUID.random_create.to_s.last(7)
  "#{name.parameterize}-#{code}"
end

def convert_field_map(field_map)
  field_map['fields'].each do |field_hash|
    field_hash['source'] = field_hash['source']&.last
  end
  field_map
end

def form_section_ruby_string(form_ids)
  "FormSection.where(unique_id: %w#{form_ids})".gsub(/\"/, '').gsub(/,/, '')
end

def primero_program_ruby_string(program_id)
  "PrimeroProgram.find_by(unique_id: '#{program_id}')"
end

def primero_module_options(object)
  {
    agency_code_indicator: object.agency_code_indicator,
    workflow_status_indicator: object.workflow_status_indicator,
    allow_searchable_ids: object.allow_searchable_ids,
    selectable_approval_types: object.selectable_approval_types,
    use_workflow_service_implemented: object.use_workflow_service_implemented,
    use_workflow_case_plan: object.use_workflow_case_plan,
    use_workflow_assessment: object.use_workflow_assessment,
    reporting_location_filter: object.reporting_location_filter,
    user_group_filter: object.user_group_filter
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
  config_hash = object.attributes.except('id', 'module_ids', 'exclude_empty_rows', 'base_language', 'primero_version').with_indifferent_access
  config_hash['module_id'] = object.module_ids.first
  config_hash['unique_id'] = generate_report_id(object.name_en)
  config_hash
end

def configuration_hash_user_group(object)
  object.attributes.except('id').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_primero_module(object)
  config_hash = object.attributes.except('id', 'associated_form_ids', 'field_map', 'program_id',
                                         'agency_code_indicator', 'workflow_status_indicator', 'allow_searchable_ids',
                                         'selectable_approval_types', 'use_workflow_service_implemented',
                                         'use_workflow_case_plan', 'use_workflow_assessment',
                                         'reporting_location_filter', 'user_group_filter').merge(unique_id(object)).with_indifferent_access
  config_hash['field_map'] = convert_field_map(object.field_map)
  config_hash['module_options'] = primero_module_options(object)

  # TODO: This a hack for now.  This will require some manual manipulation of the output script to remove quotes.  Is there a better way?
  config_hash['form_sections'] = form_section_ruby_string(object.associated_form_ids)
  config_hash['primero_program'] = primero_program_ruby_string(object.program_id)

  config_hash
end

def configuration_hash_primero_program(object)
  object.attributes.except('id').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_system_settings(object)
  object.attributes.except('id', 'default_locale', 'locales', 'primero_version', 'show_provider_note_field',
                           'set_service_implemented_on').with_indifferent_access
end

def configuration_hash_contact_information(object)
  config_hash = object.attributes.except('id').with_indifferent_access
  config_hash[:name] ||= 'administrator'
  config_hash
end

def configuration_hash_form_section(object)
  config_hash = object.attributes.except('id', 'fields')
  config_hash['fields_attributes'] = object.fields.map { |field| configuration_hash_field(field) }
  config_hash
end

def configuration_hash_field(field)
  field.attributes.except('id', 'highlight_information', 'base_language').with_indifferent_access
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
%w[Agency Lookup Report UserGroup PrimeroModule PrimeroProgram SystemSettings ContactInformation].each do |config_name|
  export_config_objects(config_name, config_objects(config_name))
end
export_forms


