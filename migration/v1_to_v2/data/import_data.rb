# frozen_string_literal: true

def records_to_import
  %w[Case Incident TracingRequest IncidentFromCase CaseTransition IncidentTransition TracingRequestTransition
     Alert Flag Recordhistory].freeze
end

puts 'Starting Import Data Script'

records_to_import.each do |record_type|
  record_type = record_type.pluralize
  path = File.dirname(__FILE__) + "/record-data-files/#{record_type.underscore}"
  next unless Dir.exist?(path)

  puts ""
  puts "Loading #{record_type}"
  puts "==================================="
  Dir["#{path}/*.rb"].each do |file_path|
    puts "-----------------------------------------------"
    puts "Loading file #{file_path}"
    puts "-----------------------------------------------"
    require_relative(file_path)
  end
end