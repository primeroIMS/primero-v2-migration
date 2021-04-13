# frozen_string_literal: true

require_relative('data_exporter.rb')

# Exports v1 Primero incident data that are linked to cases as v2 compatible ruby script files.
class LinkedIncidentDataExporter < DataExporter
  private

  def parse_object(object)
    super(object).merge(ownership_fields(object))
  end

  def model_class(_record_type)
    'Incident'
  end

  def data_hash_incident_from_case(data_hash)
    data_hash = data_hash_incident(data_hash)
    data_hash.except('incident_detail_id')
  end

  def object_hashes(object_name, objects)
    incident_case_ids = Incident.all.map(&:incident_case_id).compact
    objects.select { |child| child.incident_details.present? }.map do |child|
      next unless child.incident_details.is_a?(Array)

      # Do not create a new incident if a linked incident already exists
      next if incident_case_ids.include?(child.id)

      child.incident_details.map do |incident_detail|
        incident = Incident.make_new_incident(child.module_id, child, child.module_id, incident_detail.unique_id, nil)
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
