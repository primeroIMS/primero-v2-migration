# frozen_string_literal: true

puts 'Exporting Base Configuration Files'
require File.dirname(__FILE__) + '/exporters/base_config_exporter.rb'
base_config_exporter = BaseConfigExporter.new
base_config_exporter.export

puts 'Exporting Roles'
require File.dirname(__FILE__) + '/exporters/role_config_exporter.rb'
role_config_exporter = RoleConfigExporter.new
role_config_exporter.export

puts 'Exporting Forms'
require File.dirname(__FILE__) + '/exporters/form_config_exporter.rb'
form_config_exporter = FormConfigExporter.new
form_config_exporter.export