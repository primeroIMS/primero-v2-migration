# frozen_string_literal: true

%w[Case Incident TracingRequest].each do |record_type|
  record_type = record_type.pluralize
  path = "record-data-files/#{record_type.underscore}"
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