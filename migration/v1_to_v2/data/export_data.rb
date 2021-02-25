# frozen_string_literal: true

require_relative('exporters/record_data_exporter.rb')
data_exporter = RecordDataExporter.new(batch_size: 10)
data_exporter.export