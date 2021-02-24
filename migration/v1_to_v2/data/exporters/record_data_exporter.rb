# frozen_string_literal: true

require 'fileutils'

# Exports v1 Primero record data as v2 compatible JSON files.
class RecordDataExporter
  def initialize(export_dir: 'record-data-files', batch_size: 500)
    @export_dir = export_dir
    @batch_size = batch_size
    FileUtils.mkdir_p(@export_dir)
  end

  def export
    %w[Case Incident TracingRequest].each do |record_type|
      export_records(record_type)
    end
  end

  private

  def file_for(record_type, i)
    config_dir = "#{@export_dir}/#{record_type.pluralize.underscore}"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/#{record_type.underscore}#{i}.json"
  end

  def export_record_objects(record_type, objects, i)
    return if objects.blank?

    File.open(file_for(record_type, i), 'a') { |f| f << JSON.pretty_generate(objects) }
  end

  def migrate_notes(notes)
    notes.each do |note|
      note['note_date'] = note.delete('notes_date')
      note['note_text'] = note.delete('field_notes_subform_fields')
    end
  end

  def parse_object(object)
    # TODO: was using .compact instead of .reject but it was throwing away false values.  We want to keep those
    JSON.parse(object.to_json)&.reject { |_, v| v.nil? || v == [] }&.except('histories', '_attachments', 'other_documents', 'flags')
  end

  def record_hash_case(record_hash)
    keys = record_hash.keys
    record_hash['notes_section'] = migrate_notes(record_hash['notes_section']) if record_hash['notes_section'].present?
    record_hash['unhcr_export_opt_in'] = !record_hash.delete('unhcr_export_opt_out') if keys.include?('unhcr_export_opt_out')
    record_hash['assessment_approved'] = record_hash.delete('bia_approved') if keys.include?('bia_approved')
    record_hash['assessment_approved_date'] = record_hash.delete('bia_approved_date') if keys.include?('bia_approved_date')
    record_hash['assessment_approved_comments'] = record_hash.delete('bia_approved_comments') if keys.include?('bia_approved_comments')
    record_hash['approval_status_assessment'] = record_hash.delete('approval_status_bia') if keys.include?('approval_status_bia')
    record_hash['status'] = record_hash.delete('child_status')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    #TODO start here!!!!!!!!!!!
    record_hash.except('histories', '_attachments', 'other_documents', 'incident_details', 'transitions', 'flags', 'approval_subforms')
  end

  def record_hash_incident(record_hash)
    keys = record_hash.keys
    record_hash['short_id'] = record_hash.delete('cp_short_id') if keys.include?('cp_short_id')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    record_hash
  end

  def record_hash_tracing_request(record_hash)
    record_hash['status'] = record_hash.delete('inquiry_status')
    record_hash
  end

  def record_objects(record_type, objects)
    objects.map { |object| send("record_hash_#{record_type.underscore}", parse_object(object)) }
  end

  def export_records(record_type)
    i = 0
    model_class = record_type == 'Case' ? 'Child' : record_type
    Object.const_get(model_class).each_slice(@batch_size) do |objects|
      export_record_objects(record_type, record_objects(record_type, objects), i)
      i += 1
    end
  end
end
