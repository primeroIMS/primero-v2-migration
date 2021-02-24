# frozen_string_literal: true

require File.dirname(__FILE__) + '/exporters/base_config_exporter.rb'
base_config_exporter = BaseConfigExporter.new
base_config_exporter.export

require File.dirname(__FILE__) + '/exporters/role_config_exporter.rb'
role_config_exporter = RoleConfigExporter.new
role_config_exporter.export

require File.dirname(__FILE__) + '/exporters/form_config_exporter.rb'
form_config_exporter = FormConfigExporter.new
form_config_exporter.export

require File.dirname(__FILE__) + '/exporters/location_config_exporter.rb'
location_config_exporter = LocationConfigExporter.new
location_config_exporter.export
