# frozen_string_literal: true

require_relative('exporters/base_config_exporter.rb')
base_config_exporter = BaseConfigExporter.new
base_config_exporter.export

require_relative('exporters/lookup_config_exporter.rb')
lookup_config_exporter = LookupConfigExporter.new
lookup_config_exporter.export

require_relative('exporters/role_config_exporter.rb')
role_config_exporter = RoleConfigExporter.new
role_config_exporter.export

require_relative('exporters/form_config_exporter.rb')
form_config_exporter = FormConfigExporter.new
form_config_exporter.export

require_relative('exporters/location_config_exporter.rb')
location_config_exporter = LocationConfigExporter.new
location_config_exporter.export
