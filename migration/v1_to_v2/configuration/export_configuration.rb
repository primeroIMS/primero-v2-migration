# frozen_string_literal: true

# Script to call each of the Configuration Exporters
require_relative('exporters/base_config_exporter.rb')
require_relative('exporters/lookup_config_exporter.rb')
require_relative('exporters/role_config_exporter.rb')
require_relative('exporters/form_config_exporter.rb')
require_relative('exporters/location_config_exporter.rb')

base_config_exporter = BaseConfigExporter.new
base_config_exporter.export

lookup_config_exporter = LookupConfigExporter.new
lookup_config_exporter.export

role_config_exporter = RoleConfigExporter.new
role_config_exporter.export

form_config_exporter = FormConfigExporter.new
form_config_exporter.export

location_config_exporter = LocationConfigExporter.new
location_config_exporter.export
