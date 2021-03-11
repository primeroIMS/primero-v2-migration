# frozen_string_literal: true

# Script to call each of the Data Exporters
require_relative('exporters/record_data_exporter.rb')
require_relative('exporters/linked_incident_data_exporter.rb')

data_exporter = RecordDataExporter.new(batch_size: 250)
data_exporter.export

data_exporter = LinkedIncidentDataExporter.new(batch_size: 250)
data_exporter.export