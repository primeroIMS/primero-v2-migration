# frozen_string_literal: true

# Script to call each of the User Exporters
# Args:     locale_hash - colon separated list of locales that are changing
#                         if changing from ar to ar-IQ, pass in ar:ar-IQ
#
# Example:  $ rails r ./tmp/users/export_users.rb
#               ** this exports users without changing any locales ***
#
# Example:  $ rails r ./tmp/users/export_users.rb ar:ar-IQ
#               ** this exports users, if any of those users has a locale of ar, it changes it to ar-IQ ***
#
# Example:  $ rails r ./tmp/users/export_users.rb ar:ar-IQ:ku:ku-IQ
#               ** this exports users, changing ar to ar-IQ and ku to ku-IQ ***

require_relative('exporters/users_exporter.rb')
require_relative('exporters/saved_searches_exporter.rb')

def exporters
  %w[UsersExporter SavedSearchesExporter].freeze
end

timestamp = DateTime.now.strftime('%Y%m%d%H%M%S')
export_dir = "seed-files-#{timestamp}"
locale_hash = (ARGV[0].present? && ARGV[0].is_a?(String)) ? Hash[*ARGV[0].split(':').flatten(1)] : {}
exporters.each do |exporter|
  data_exporter = Object.const_get(exporter).new(export_dir: export_dir, batch_size: 250, locale_hash: locale_hash)
  data_exporter.export
end