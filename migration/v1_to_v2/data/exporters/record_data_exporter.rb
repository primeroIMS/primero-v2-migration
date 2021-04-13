# frozen_string_literal: true

require_relative('data_exporter.rb')

# Exports v1 Primero record data as v2 compatible JSON files.
class RecordDataExporter < DataExporter
  private

  def parse_object(object)
    super(object).merge(ownership_fields(object))
  end

  def migrate_notes(notes)
    notes.each do |note|
      note['note_date'] = note.delete('notes_date')
      note['note_text'] = note.delete('field_notes_subform_fields')
    end
  end

  def data_hash_case(data_hash)
    keys = data_hash.keys
    data_hash['notes_section'] = migrate_notes(data_hash['notes_section']) if data_hash['notes_section'].present?
    data_hash['unhcr_export_opt_in'] = !data_hash.delete('unhcr_export_opt_out') if keys.include?('unhcr_export_opt_out')
    data_hash['assessment_approved'] = data_hash.delete('bia_approved') if keys.include?('bia_approved')
    data_hash['assessment_approved_date'] = data_hash.delete('bia_approved_date') if keys.include?('bia_approved_date')
    data_hash['assessment_approved_comments'] = data_hash.delete('bia_approved_comments') if keys.include?('bia_approved_comments')
    data_hash['approval_status_assessment'] = data_hash.delete('approval_status_bia') if keys.include?('approval_status_bia')
    data_hash['status'] = data_hash.delete('child_status')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    data_hash.except('other_documents', 'photo_keys', 'current_photo_key', 'document_keys', 'audio_attachments',
                     'recorded_audio', 'incident_details', 'transitions', 'flags', 'approval_subforms')
  end

  def data_hash_tracing_request(data_hash)
    data_hash['status'] = data_hash.delete('inquiry_status')
    data_hash
  end

  def data_object_names
    %w[Case Incident TracingRequest]
  end
end
