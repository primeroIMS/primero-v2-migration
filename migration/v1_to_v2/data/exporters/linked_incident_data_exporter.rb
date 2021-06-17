# frozen_string_literal: true

require_relative('data_exporter.rb')

# Exports v1 Primero incident data that are linked to cases as v2 compatible ruby script files.
class LinkedIncidentDataExporter < DataExporter
  private
  def parse_object(object)
    super(object).merge(ownership_fields(object))
  end

  def default_user
    @default_user ||= User.new(
      user_name: 'migration_system_user',
      full_name: 'Migration System User',
      send_mail: 'false',
      disabled: 'true',
      organization: Agency.all.select{|agency| agency.name_en == 'UNICEF'}.first.id,
      role_ids: [Role.by_name(key: "Superuser").first.id],
      module_ids: PrimeroModule.all.map(&:id),
      user_group_ids: UserGroup.all.map(&:id)
    )
  end

  def copy_case_owner_fields(child, incident)
    incident.owned_by_agency = child&.owned_by_agency
    incident.owned_by_agency_id = child&.owned_by_agency
    incident.owned_by_groups = child&.owned_by_groups
    incident.owned_by_location = child&.owned_by_location
    incident.owned_by_user_code = child&.owned_by_user_code
    incident.owned_by_agency_office = child&.owned_by_agency_office

    incident.assigned_user_names = []
    incident.associated_user_names = [child.owned_by]
    # On V2 associated_user_groups are the usergroups of the associated_user_names, in this case only owned_by
    incident.associated_user_groups = [ child&.owned_by_groups]
    # On V2 associated_user_agencies are the agencies of the associated_user_names, in this case only owned_by
    incident.associated_user_agencies = [child&.owned_by_agency]
    incident
  end

  def model_class(_record_type)
    'Incident'
  end

  def identification_fields
    data_hash = {}
    data_hash['unique_identifier'] = UUIDTools::UUID.random_create.to_s
    data_hash['short_id'] = data_hash['unique_identifier'].last 7
    data_hash['incident_id'] = data_hash['unique_identifier']
    data_hash
  end

  def data_hash_incident_from_case(data_hash)
    data_hash = data_hash_incident(data_hash).merge(identification_fields)
    data_hash.except('incident_detail_id')
  end

  def object_hashes(object_name, objects)
    incident_case_ids = Incident.all.map(&:incident_case_id).compact
    objects.select { |child| child.incident_details.present? }.map do |child|
      next unless child.incident_details.is_a?(Array)

      # Do not create a new incident if a linked incident already exists
      next if incident_case_ids.include?(child.id)

      child.incident_details.map do |incident_detail|
        incident = Incident.make_new_incident(child.module_id, child, child.module_id, incident_detail.unique_id,
                                              default_user)
        incident = copy_case_owner_fields(child, incident)
        object_data_hash(object_name, incident)
      end
    end.flatten
  end

  def object_query(_object_name)
    Child
  end

  def data_object_names
    %w[IncidentFromCase]
  end
end
