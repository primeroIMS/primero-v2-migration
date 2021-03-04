# frozen_string_literal: true

require_relative('exporters/record_data_exporter.rb')
data_exporter = RecordDataExporter.new(batch_size: 500)
data_exporter.export

require_relative('exporters/linked_incident_data_exporter.rb')
data_exporter = LinkedIncidentDataExporter.new(batch_size: 500)
data_exporter.export