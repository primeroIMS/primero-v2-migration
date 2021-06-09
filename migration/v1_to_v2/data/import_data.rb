# frozen_string_literal: true

# Script to run the generated data import scripts
def records_to_import
  %w[Case Incident TracingRequest IncidentFromCase CaseTransition IncidentTransition TracingRequestTransition
     CaseAttachment IncidentAttachment TracingRequestAttachment Alert Flag RecordHistory Trace].freeze
end

def record_names
  %w[Child Incident TracingRequest Transition Attachment Alert Flag RecordHistory Trace].freeze
end

def print_record_counts
  puts ''
  puts "==================================="
  puts 'Record Counts'
  puts "==================================="
  record_names.each { |record_name| puts "#{record_name}: #{Object.const_get(record_name).count}" }
  puts ''
end

puts 'Starting Import Data Script'
print_record_counts
records_to_import.each do |record_type|
  record_type = record_type.pluralize
  path = File.dirname(__FILE__) + "/record-data-files/#{record_type.underscore}"
  next unless Dir.exist?(path)

  puts ''
  puts "==================================="
  puts "Loading #{record_type}"
  puts "==================================="
  Dir["#{path}/*.rb"].each do |file_path|
    puts "-----------------------------------------------"
    puts "Loading file #{file_path}"
    puts "-----------------------------------------------"
    require_relative(file_path)
  end
end
print_record_counts