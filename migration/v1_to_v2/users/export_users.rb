# frozen_string_literal: true

# Script to call each of the Data Exporters
require_relative('exporters/users_exporter.rb')
require_relative('exporters/saved_searches_exporter.rb')

def exporters
  %w[UsersExporter SavedSearchesExporter].freeze
end

exporters.each do |exporter|
  data_exporter = Object.const_get(exporter).new(batch_size: 250)
  data_exporter.export
end