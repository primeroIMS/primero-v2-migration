# frozen_string_literal: true

require_relative('configuration_exporter.rb')

# Exports the current v1.7 or v1.6 state of the Primero configuration as v2 compatible Ruby scripts.
class BaseConfigExporter < ConfigurationExporter
  private

  def approvals_labels
    {
      assessment: 'SER',
      case_plan: 'Case Plan',
      closure: 'Closure',
      action_plan: 'Action Plan',
      gbv_closure: 'GBV Closure'
    }
  end

  def generate_report_id(name)
    code = UUIDTools::UUID.random_create.to_s.last(7)
    "#{name.parameterize}-#{code}"
  end

  def convert_field_map(field_map)
    field_map['fields'] = field_map['fields'].map do |f|
      {'source' => f['source'].last, 'target' => f['target']} if f['source'].first != 'incident_details'
    end.compact
    field_map
  end

  def convert_reporting_location_config(reporting_location_config)
    reporting_location_hash = reporting_location_config.attributes.except('admin_level_map', 'reg_ex_filter')
    reporting_location_hash['admin_level_map'] = reporting_location_config.admin_level_map.map { |k, v| [v, [k]] }.to_h
    reporting_location_hash
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
    object.attributes.except('id', 'base_language', 'core_resource').merge(unique_id(object)).with_indifferent_access
  end

  def configuration_hash_report(object)
    config_hash = object.attributes.except('id', 'module_ids', 'exclude_empty_rows', 'base_language',
                                           'primero_version').with_indifferent_access
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
                                           'reporting_location_filter',
                                           'user_group_filter').merge(unique_id(object)).with_indifferent_access
    config_hash['field_map'] = convert_field_map(object.field_map)
    config_hash['module_options'] = primero_module_options(object)
    config_hash['form_sections'] = form_section_ruby_string(object.associated_form_ids - retired_forms)
    config_hash['primero_program'] = primero_program_ruby_string(object.program_id)

    config_hash
  end

  def configuration_hash_primero_program(object)
    config_hash = object.attributes.except('id', 'name', 'description').merge(unique_id(object)).with_indifferent_access
    config_hash['name_en'] = object.name
    config_hash['description_en'] = object.description
    config_hash
  end

  def configuration_hash_system_settings(object)
    config_hash = object.attributes.except('id', 'default_locale', 'locales', 'primero_version',
                                           'show_provider_note_field', 'set_service_implemented_on',
                                           'reporting_location_config').with_indifferent_access
    config_hash['reporting_location_config'] = convert_reporting_location_config(object.reporting_location_config)
    config_hash['approvals_labels_en'] = approvals_labels
    config_hash
  end

  def configuration_hash_contact_information(object)
    config_hash = object.attributes.except('id').with_indifferent_access
    config_hash[:name] ||= 'administrator'
    config_hash
  end

  def configuration_hash_export_configuration(object)
    config_hash = object.attributes.except('id').with_indifferent_access
    config_hash['unique_id'] = "export-#{object&.export_id&.dasherize}"
    config_hash
  end

  def config_object_names
    %w[SystemSettings Agency Report UserGroup PrimeroModule PrimeroProgram ContactInformation
       ExportConfiguration]
  end
end
