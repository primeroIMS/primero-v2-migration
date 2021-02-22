# frozen_string_literal: true

# Exports the current state of the Primero configuration as v2 compatible Ruby scripts.
# This was copied from the primero_v2 project: app/models/exporters/ruby_config_exporter.rb.
# It was modified to be stand-alone script that can be run on a v1.7 or v1.6 system.
# TODO: The exporter does not account for Location, User

require 'fileutils'

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

# These forms are now hard coded in v2 and the form configs are no longer needed
def retired_forms
  %w[approvals approval_subforms referral_transfer record_owner incident_record_owner cp_incident_record_owner
     transitions reopened_logs]
end

def forms_with_subforms
  return @forms_with_subforms if @forms_with_subforms.present?

  fs = FormSection.all.reject(&:is_nested).group_by(&:unique_id)
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
  file_name = file_for(config_name, objects)
  File.open(file_name, 'a') do |f|
    objects.each do |config_object|
      f << config_to_ruby_string(config_name, config_object)
    end
  end
end

def config_to_ruby_string(config_name, config_hash)
  ruby_string = config_hash['unique_id'].present? ? "#{i}#{config_name}.create_or_update!(\n" : "#{i}#{config_name}.create!(\n"
  _i
  ruby_string += "#{i}#{value_to_ruby_string(config_hash)}"
  i_
  ruby_string += "\n#{i})\n"

  # The nil is necessary to distinguish between roles that have no form restrictions vs roles that have form
  # restrictions, but all of their allowed forms are retired.
  ruby_string += role_form_ruby_string(config_hash['unique_id']) + "\n" if config_name == 'Role' && config_hash['form_section_read_write'].nil?
  ruby_string + "\n"
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
  field_map['fields'].each do |field_hash|
    field_hash['source'] = field_hash['source']&.last
  end
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

def role_form_ruby_string(role_id)
  "Role.find_by(unique_id: '#{role_id}')&.associate_all_forms"
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

def modules_for_superuser
  PrimeroModule.all.map(&:id)
end

def role_module(object)
  return modules_for_superuser if object.id == 'role-superuser'

  return [PrimeroModule::GBV] if object.id.include?('gbv')

  return [PrimeroModule::MRM] if object.id.include?('mrm')

  [PrimeroModule::CP]
end

def role_permitted_form_hash(permitted_form_ids)
  # The nil is necessary to distinguish between roles that have no form restrictions vs roles that have form
  # restrictions, but all of their allowed forms are retired.
  permitted_form_ids.present? ? (permitted_form_ids - retired_forms).map { |f| [f, 'r,w'] }.to_h : nil
end

def role_forms(permitted_form_ids)
  permitted_form_ids.present? ? forms_with_subforms.select { |k,_| permitted_form_ids.include?(k) } : forms_with_subforms
end

def role_form_ids(permitted_form_ids)
  forms = role_forms(permitted_form_ids)
  return [] if forms.blank?

  forms.values.flatten.map(&:unique_id)
end

def incident_from_case?(actions, opts = {})
  form_ids = role_form_ids(opts[:permitted_form_ids])
  return false if form_ids.blank?

  (opts[:module_unique_ids].include?('primeromodule-cp') && form_ids.include?('incident_details_container')) ||
  (opts[:module_unique_ids].include?('primeromodule-gbv') && actions.include?('write') && form_ids.include?('action_plan_form'))
end

def permission_actions_incident_from_case(actions, opts = {})
  return [] unless incident_from_case?(actions, opts)

  new_actions = []
  new_actions << 'view_incident_from_case' if actions.include?('read')
  new_actions << 'incident_from_case'  if (actions & %w[create write]).any?
  new_actions
end

def permission_actions_case_close_reopen(actions, opts = {})
  return [] unless actions.include?('write')

  form_ids = role_form_ids(opts[:permitted_form_ids])
  return [] if form_ids.blank? || form_ids.exclude?('basic_identity')

  ['close', 'reopen']
end

def permission_actions_case(actions, opts = {})
  return [] if actions.blank?

  new_actions = actions - %w[export_case_pdf export_child_pdf request_approval_bia approve_bia]
  new_actions << 'export_pdf' if (actions & %w[export_case_pdf export_child_pdf]).any?
  new_actions << 'request_approval_assessment' if actions.include?('request_approval_bia')
  new_actions << 'approve_assessment' if actions.include?('approve_bia')
  new_actions << 'enable_disable' if actions.include?('write')
  new_actions << 'change_log' if opts[:permitted_form_ids].blank?
  new_actions += permission_actions_incident_from_case(actions, opts)
  new_actions += permission_actions_case_close_reopen(actions, opts)
  new_actions.uniq
end

def permission_actions_incident(actions, opts = {})
  return [] if actions.blank?

  new_actions = actions - %w[export_photowall export_unhcr_csv assign request_approval_bia request_approval_case_plan
                             request_approval_closure]
  new_actions << 'enable_disable' if actions.include?('write')
  new_actions << 'change_log' if opts[:permitted_form_ids].blank?
  new_actions.uniq
end

def permission_actions_tracing_request(actions, opts = {})
  return [] if actions.blank?

  new_actions = actions - %w[export_photowall export_unhcr_csv assign export_xls]
  new_actions << 'enable_disable' if actions.include?('write')
  new_actions << 'change_log' if opts[:permitted_form_ids].blank?
  new_actions.uniq
end

def receive_permissions?(actions)
  return [] if actions.blank?

  (actions & %w[receive_referral receive_transfer]).any?
end

def share_permissions?(actions)
  return [] if actions.blank?

  (actions & %w[referral transfer referral_from_service]).any?
end

def permission_actions_dashboard_approval(opts = {})
  actions = []
  actions << 'approvals_assessment' if opts[:case_permissions]&.include?('request_approval_bia')
  actions << 'approvals_assessment_pending' if opts[:case_permissions]&.include?('approve_bia')
  actions << 'approvals_case_plan' if opts[:case_permissions]&.include?('request_approval_case_plan')
  actions << 'approvals_case_plan_pending' if opts[:case_permissions]&.include?('approve_case_plan')
  actions << 'approvals_closure' if opts[:case_permissions]&.include?('request_approval_closure')
  actions << 'approvals_closure_pending' if opts[:case_permissions]&.include?('approve_closure')
  actions
end

def permission_task_overdue_services?(field_names)
  (!system_settings.due_date_from_appointment_date && field_names.include?('service_response_timeframe')) ||
    (system_settings.due_date_from_appointment_date && field_names.include?('service_appointment_date'))
end

def permission_actions_dashboard_task_overdue(field_names)
  new_actions = []
  new_actions << 'dash_cases_by_task_overdue_assessment' if field_names.include?('assessment_requested_on')
  new_actions << 'dash_cases_by_task_overdue_case_plan' if field_names.include?('case_plan_due_date')
  new_actions << 'dash_cases_by_task_overdue_services' if permission_task_overdue_services?(field_names)
  new_actions << 'dash_cases_by_task_overdue_followups' if field_names.include?('followup_needed_by_date')
  new_actions
end

def permission_actions_form_dependent(actions, opts = {})
  forms = role_forms(opts[:permitted_form_ids])
  return [] if forms.blank?

  form_ids = forms.values.flatten.map(&:unique_id)
  field_names = forms.map {|_,v| v.map {|form| form.fields.map { |field| field.name if field.visible? }}}.flatten.compact
  new_actions = []
  new_actions << 'dash_case_incident_overview' if form_ids.include?('incident_details_container')
  new_actions += permission_actions_dashboard_task_overdue(field_names) if actions.include?('dash_cases_by_task_overdue')
  new_actions
end

def permission_actions_dashboard_shared(opts = {})
  new_actions = []
  new_actions << 'dash_shared_with_me' if opts[:view_assessment] || receive_permissions?(opts[:case_permissions])
  new_actions << 'dash_shared_with_others' if share_permissions?(opts[:case_permissions])
  new_actions
end

def permission_actions_dashboard_overview(opts = {})
  new_actions = []
  new_actions << 'dash_case_overview' if opts[:group_permission] == 'self'
  new_actions << 'dash_group_overview' if ['group', 'all'].include?(opts[:group_permission])
  new_actions
end

def permission_actions_dashboard(actions, opts = {})
  return [] if actions.blank?

  new_actions = actions - %w[view_approvals view_assessment dash_cases_by_workflow dash_cases_by_task_overdue
                             dash_manager_transfers dash_referrals_by_socal_worker dash_transfers_by_socal_worker]
  new_actions << 'case_risk' if actions.include?('view_assessment')
  new_actions << 'dash_workflow_team' if actions.include?('dash_cases_by_workflow')
  new_actions << 'dash_shared_with_my_team' if actions.include?('dash_referrals_by_socal_worker')
  new_actions << 'dash_shared_from_my_team' if actions.include?('dash_transfers_by_socal_worker')
  new_actions += permission_actions_dashboard_overview(opts)
  new_actions += permission_actions_dashboard_shared(view_assessment: actions.include?('view_assessment'), case_permissions: opts[:case_permissions])
  new_actions += permission_actions_dashboard_approval(opts) if actions.include?('view_approvals')
  new_actions += permission_actions_form_dependent(actions, opts)
  new_actions.uniq
end

def default_dashboard_permissions(opts = {})
  new_actions = permission_actions_dashboard_overview(opts)
  new_actions += permission_actions_dashboard_shared(view_assessment: false, case_permissions: opts[:case_permissions])
  new_actions
end

def permission_actions(permission, opts = {})
  resources_to_modify = %w[case incident tracing_request dashboard]
  return permission.actions unless resources_to_modify.include?(permission.resource)

  send("permission_actions_#{permission.resource}", permission.actions, opts)
end

def case_permissions(permissions)
  permissions.select{|p| p.resource == 'case'}.first&.actions
end

def add_incident_from_case?(permissions, permission, opts = {})
  return false unless permission.resource == 'case' && permissions.map(&:resource).exclude?('incident')

  form_ids = role_form_ids(opts[:permitted_form_ids])
  form_ids&.include?('incident_details_container') ? true : false
end

def incident_permissions_from_case(case_permission)
  new_actions = []
  new_actions << 'read' if case_permission.actions.include?('read')
  new_actions << 'write' if (case_permission.actions & %w[create write]).any?
  new_actions
end

def role_permissions(permissions, opts = {})
  object_hash = {}
  json_hash = permissions.inject({}) do |hash, permission|
    opts[:case_permissions] = case_permissions(permissions) if permission.resource == 'dashboard'
    hash[permission.resource] = permission_actions(permission, opts)
    hash['incident'] = incident_permissions_from_case(permission) if add_incident_from_case?(permissions, permission, opts)
    object_hash[Permission::AGENCY] = permission.agency_ids if permission.agency_ids.present?
    object_hash[Permission::ROLE] = permission.role_ids if permission.role_ids.present?
    hash
  end
  if json_hash.keys.exclude?('dashboard')
    opts[:case_permissions] = case_permissions(permissions)
    json_hash['dashboard'] = default_dashboard_permissions(opts)
  end
  json_hash['objects'] = object_hash
  json_hash
end

def configuration_hash_agency(object)
  # TODO: handle logo
  object.attributes.except('id', 'base_language', 'core_resource').merge(unique_id(object)).with_indifferent_access
end

def configuration_hash_lookup(object)
  object.attributes.except('id', 'base_language', 'editable').merge(unique_id(object)).with_indifferent_access
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

def configuration_hash_role(object)
  config_hash = object.attributes.except('id', 'permissions_list', 'permitted_form_ids').merge(unique_id(object)).with_indifferent_access
  config_hash['is_manager'] = ['all', 'group'].include?(object.group_permission)
  config_hash['module_unique_ids'] = role_module(object)
  config_hash['permissions'] = role_permissions(object.permissions_list, permitted_form_ids: object.permitted_form_ids,
                                                group_permission: object.group_permission,
                                                module_unique_ids: config_hash['module_unique_ids'])
  config_hash['form_section_read_write'] = role_permitted_form_hash(object.permitted_form_ids)
  config_hash
end

def configuration_hash_form_section(object)
  config_hash = object.attributes.except('id', 'fields', 'base_language', 'collapsed_fields', 'fixed_order',
                                         'perm_visible', 'perm_enabled', 'validations')
  config_hash['fields_attributes'] = object.fields.map { |field| configuration_hash_field(field, object.collapsed_fields, object.unique_id) }
  config_hash
end

def configuration_hash_field(field, collapsed_fields, form_unique_id)
  config_hash = field.attributes.except('id', 'highlight_information', 'base_language', 'deletable', 'searchable_select',
                                        'create_property', 'subform_section_id').with_indifferent_access
  config_hash['collapsed_field_for_subform_unique_id'] = form_unique_id if collapsed_fields.include?(field.name)
  config_hash['subform_unique_id'] = field.subform_section_id if field.type == 'subform'
  config_hash['disabled'] = false if field.type.include?('upload_box')
  if form_unique_id == 'notes_section'
    config_hash['name'] = 'note_date' if config_hash['name'] == 'notes_date'
    config_hash['name'] = 'note_text' if config_hash['name'] == 'field_notes_subform_fields'
  end
  config_hash['option_strings_source'] = field.option_strings_source.split(' ').first if field.option_strings_source&.include?('use_api')
  config_hash
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

def system_settings
  @system_settings ||= SystemSettings.current
  @system_settings
end

# TODO: Location, User(?)
def config_object_names
  %w[Agency Lookup Report UserGroup PrimeroModule PrimeroProgram ContactInformation ExportConfiguration Role]
end

###################################
# Beginning of script
###################################
@indent = 0
@export_dir = 'seed-files'
FileUtils.mkdir_p(@export_dir)


#SystemSettings goes first because Role depends on it
export_config_objects('SystemSettings', [configuration_hash_system_settings(system_settings)])

config_object_names.each do |config_name|
  export_config_objects(config_name, config_objects(config_name))
end
export_forms
