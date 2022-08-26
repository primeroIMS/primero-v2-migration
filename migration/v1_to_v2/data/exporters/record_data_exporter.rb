# frozen_string_literal: true

require_relative('data_exporter.rb')

# Exports v1 Primero record data as v2 compatible JSON files.
class RecordDataExporter < DataExporter
  private

  def initialize(options = {})
    super(options)
    @radio_fields = get_radio_fields
  end

  def parse_object(object)
    super(object).merge(ownership_fields(object))
  end

  def migrate_notes(notes)
    notes.each do |note|
      note['note_date'] = note.delete('notes_date')
      note['note_text'] = note.delete('field_notes_subform_fields')
    end
  end

  def get_radio_fields
    primero_module = PrimeroModule.find_by_name("CP")  #hardcoded for now. need to change it to accomodate either one. Cannot use all since there comflicting fields in both modules
    formsections   = primero_module.associated_forms(true)
    radio_fields   = []
    formsections.each do |form|
      radio_fields << form.fields.map{ |s| s.name if s.visible == true && s.type == "radio_button" && s.option_strings_source == "lookup lookup-yes-no" }.compact
    end
    return radio_fields.flatten.compact
  end

  def value_to_ruby_string(value, include_blank = false)
    return 'nil' if include_blank && value.nil?

    puts value

    if value.is_a?(Hash)
      ruby_string = "{\n"
      _i
      ruby_string += i
      # TODO: was using .compact instead of .reject but it was throwing away false values.  We want to keep those
      ruby_string += (include_blank ? value : value.reject { |_, v| v.nil? || v == [] }).map do |k,v|
        if @radio_fields.include?(k)
          "#{key_to_ruby(k)}: \"#{v}\""
        else
          "#{key_to_ruby(k)}: #{value_to_ruby_string(v, include_blank)}"
        end
      end.join(",\n#{i}")
      i_
      ruby_string + "\n#{i}}"
    elsif value.is_a?(Array)
      array_value_to_ruby_string(value, include_blank)
    elsif value.is_a?(Range)
      value
    elsif value.is_a?(String) && (value.include?('.parse(') || value.include?('.find_by('))
      value
    else
      value.to_json
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
    data_hash['reassigned_transferred_on'] = data_hash.delete('reassigned_tranferred_on') if keys.include?('reassigned_tranferred_on')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    data_hash.except('other_documents', 'photo_keys', 'current_photo_key', 'document_keys', 'audio_attachments',
                     'recorded_audio', 'incident_details', 'transitions', 'flags')
  end

  def data_hash_tracing_request(data_hash)
    data_hash['status'] = data_hash.delete('inquiry_status')

    # These are stored in separate tables in v2.  They will be migrated in other scripts
    data_hash.except('tracing_request_subform_section')
  end

  def data_object_names
    %w[Case Incident TracingRequest]
  end
end
