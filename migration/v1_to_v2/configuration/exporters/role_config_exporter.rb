# frozen_string_literal: true

# Exports the current state of the Primero roles configuration as v2 compatible Ruby scripts.
require File.dirname(__FILE__) + '/configuration_exporter.rb'

class RoleConfigExporter < ConfigurationExporter

  private

  def config_to_ruby_string(config_name, config_hash)
    ruby_string = super
    # The nil is necessary to distinguish between roles that have no form restrictions vs roles that have form
    # restrictions, but all of their allowed forms are retired.
    ruby_string += role_form_ruby_string(config_hash['unique_id']) + "\n\n" if config_hash['form_section_read_write'].nil?
    ruby_string
  end

  def role_form_ruby_string(role_id)
    "Role.find_by(unique_id: '#{role_id}')&.associate_all_forms"
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
    permitted_form_ids.present? ? (permitted_form_ids - retired_forms).map { |f| [f, 'rw'] }.to_h : nil
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

  def config_object_names
    %w[Role]
  end
end