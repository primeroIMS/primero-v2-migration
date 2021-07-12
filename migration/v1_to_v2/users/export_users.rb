# frozen_string_literal: true

# Script to call each of the Data Exporters
require_relative('exporters/users_exporter.rb')
require_relative('exporters/saved_searches_exporter.rb')

def exporters
  %w[UsersExporter SavedSearchesExporter].freeze
end

locale_hash = (ARGV[0].present? && ARGV[0].is_a?(String)) ? Hash[*ARGV[0].split(':').flatten(1)] : {}
exporters.each do |exporter|
  data_exporter = Object.const_get(exporter).new(batch_size: 250, locale_hash: locale_hash)
  data_exporter.export
end