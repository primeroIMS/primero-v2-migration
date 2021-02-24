# frozen_string_literal: true

# Exports the current state of the Primero roles configuration as v2 compatible Ruby scripts.
require File.dirname(__FILE__) + '/configuration_exporter.rb'

class FormConfigExporter < ConfigurationExporter

  def export
    forms_with_subforms.each do |_, form_with_subforms|
      forms_hash = form_with_subforms.map { |form| configuration_hash_form_section(form) }
      export_config_objects('FormSection', forms_hash)
    end
  end

  private

  def file_for(opts = {})
    return if opts[:config_objects].blank?

    config_dir = "#{@export_dir}/forms/#{opts[:config_objects].last['parent_form']}"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/#{opts[:config_objects].last['unique_id']}.rb"
  end

  def configuration_hash_form_section(object)
    config_hash = object.attributes.except('id', 'fields', 'base_language', 'collapsed_fields', 'fixed_order',
                                           'perm_visible', 'perm_enabled', 'validations')
    config_hash['fields_attributes'] = object.fields.map { |field| configuration_hash_field(field, object.collapsed_fields, object.unique_id) }
    config_hash
  end

  def configuration_hash_field_name(config_hash, form_unique_id)
    if form_unique_id == 'notes_section'
      config_hash['name'] = 'note_date' if config_hash['name'] == 'notes_date'
      config_hash['name'] = 'note_text' if config_hash['name'] == 'field_notes_subform_fields'
    end
    config_hash['name'] = 'other_documents' if config_hash['name'] == 'upload_other_document'
    config_hash['name'] = 'status' if %w[child_status inquiry_status].include?(config_hash['name'])
    config_hash['name'] = 'unhcr_export_opt_in' if config_hash['name'] == 'unhcr_export_opt_out'
    config_hash['name'] = config_hash['name'].gsub(/bia/, 'assessment') if config_hash['name'].include?('bia_approved')
    config_hash['name'] = 'approval_status_assessment' if config_hash['name'] == 'approval_status_bia'
    config_hash['name'] = 'short_id' if config_hash['name'] == 'cp_short_id'
    config_hash
  end

  def configuration_hash_field(field, collapsed_fields, form_unique_id)
    config_hash = field.attributes.except('id', 'highlight_information', 'base_language', 'deletable', 'searchable_select',
                                          'create_property', 'subform_section_id').with_indifferent_access
    config_hash['collapsed_field_for_subform_unique_id'] = form_unique_id if collapsed_fields.include?(field.name)
    config_hash['subform_unique_id'] = field.subform_section_id if field.type == 'subform'
    config_hash['disabled'] = false if field.type.include?('upload_box')
    config_hash['option_strings_source'] = field.option_strings_source.split(' ').first if field.option_strings_source&.include?('use_api')
    config_hash = configuration_hash_field_name(config_hash, form_unique_id)
    config_hash
  end
end