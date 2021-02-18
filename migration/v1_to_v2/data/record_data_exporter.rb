# frozen_string_literal: true

# Exports v1 Primero record data as v2 compatible JSON files.

require 'fileutils'

def initialize(export_dir: 'record-data-files', file: nil)
  @export_dir = export_dir
  FileUtils.mkdir_p(@export_dir)
  @file = file
  FileUtils.rm("#{@export_dir}/#{@file}") if @file && File.exist?("#{@export_dir}/#{@file}")
end

def file_for(record_type)
  return "#{@export_dir}/#{@file}" if @file

  "#{@export_dir}/#{record_type.underscore}.json"
end

def export_record_objects(record_type, objects)
  return if objects.blank?

  File.open(file_for(record_type), 'a') { |f| f << JSON.pretty_generate(objects) }
end

def migrate_notes(notes)
  notes.each do |note|
    note['note_date'] = note.delete('notes_date')
    note['note_text'] = note.delete('field_notes_subform_fields')
  end
end

def record_hash_child(object)
  # TODO: WIP
  # TODO: need to figure out how to migrate attachments.  Is that a different ticket?
  record_hash = JSON.parse(object.to_json)
  keys = record_hash.keys
  record_hash['notes_section'] = migrate_notes(record_hash['notes_section']) if record_hash['notes_section'].present?
  record_hash['unhcr_export_opt_in'] = !record_hash.delete('unhcr_export_opt_out') if keys.include?('unhcr_export_opt_out')
  record_hash['status'] = record_hash.delete('child_status')
  record_hash
end

def record_hash_incident(object)
  # TODO
  JSON.parse(object.to_json)
end

def record_hash_tracing_request(object)
  # TODO: WIP
  record_hash = JSON.parse(object.to_json)
  record_hash['status'] = record_hash.delete('inquiry_status')
  record_hash
end

def record_objects(record_type)
  Object.const_get(record_type).all.map { |object| send("record_hash_#{record_type.underscore}", object) }
end

###################################
# Beginning of script
###################################
initialize

%w[Child Incident TracingRequest].each do |record_type|
  export_record_objects(record_type, record_objects(record_type))
end