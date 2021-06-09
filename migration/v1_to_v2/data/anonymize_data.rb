# frozen_string_literal: true

# Script to call Data Anonymizer
# Args:     record_types -  Record types to process -  default:  ['Case', 'Incident', 'TracingRequest']
#           field_map_file - JSON file containing implementation specific fields to be anonymized
#
# Example:  $ rails r ./tmp/data/anonymize_data.rb 'Case||Incident' './tmp/anonymize_field_map.json'
require_relative('anonymizers/data_anonymizer.rb')

record_types = ARGV[0].present? ? ARGV[0].split('||') : %w[Case Incident TracingRequest]
field_map_file = ARGV[1] || nil
data_anonymizer = DataAnonymizer.new(batch_size: 250, record_types: record_types, field_map_file: field_map_file)
data_anonymizer.anonymize