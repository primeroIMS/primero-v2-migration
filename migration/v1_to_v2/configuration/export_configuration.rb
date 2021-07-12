# frozen_string_literal: true

# Script to call each of the Configuration Exporters
require_relative('exporters/base_config_exporter.rb')
require_relative('exporters/agency_logo_exporter.rb')
require_relative('exporters/lookup_config_exporter.rb')
require_relative('exporters/role_config_exporter.rb')
require_relative('exporters/form_config_exporter.rb')
require_relative('exporters/location_config_exporter.rb')
require_relative('exporters/system_settings_config_exporter.rb')

def exporters
  %w[SystemSettingsConfigExporter BaseConfigExporter AgencyLogoExporter LookupConfigExporter RoleConfigExporter
     FormConfigExporter LocationConfigExporter].freeze
end

exporters.each do |exporter|
  config_exporter = Object.const_get(exporter).new(batch_size: 250)
  config_exporter.export
end
