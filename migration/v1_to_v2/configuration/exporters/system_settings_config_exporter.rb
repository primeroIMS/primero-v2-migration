# frozen_string_literal: true

require_relative('configuration_exporter.rb')

# Exports the current v1 state of the Primero roles configuration as v2 compatible Ruby scripts.
class SystemSettingsConfigExporter < ConfigurationExporter
  private

  CREATE_OR_UPDATE = [
    "def create_or_update_system_setting(setting_hash)",
    "  # There should only be 1 row in system settings",
    "  system_setting = SystemSettings.first",
    "  if system_setting.nil?",
    "    puts 'Creating System Settings '",
    "    SystemSettings.create!(setting_hash)",
    "  else",
    "    puts 'Updating System Settings'",
    "    system_setting.update_attributes setting_hash",
    "  end",
    "end\n"
  ].join("\n").freeze

  def config_to_ruby_string(config_name, config_hash)
    ruby_string = CREATE_OR_UPDATE
    ruby_string += "#{i}create_or_update_system_setting(\n"
    _i
    ruby_string += "#{i}#{value_to_ruby_string(config_hash)}"
    i_
    ruby_string + "\n#{i})\n\n"
  end

  def convert_reporting_location_config(reporting_location_config)
    reporting_location_hash = reporting_location_config.attributes.except('admin_level_map', 'reg_ex_filter', 'label_key')
    reporting_location_hash['admin_level_map'] = reporting_location_config.admin_level_map.map { |k, v| [v, [k]] }.to_h
    reporting_location_hash['admin_level_map'][reporting_location_config.admin_level] = [reporting_location_config.label_key]
    reporting_location_hash
  end

  def configuration_hash_system_settings(object)
    config_hash = object.attributes.except('id', 'default_locale', 'locales', 'primero_version',
                                           'show_provider_note_field', 'set_service_implemented_on',
                                           'reporting_location_config').with_indifferent_access
    config_hash['reporting_location_config'] = convert_reporting_location_config(object.reporting_location_config)
    I18n.available_locales.each { |locale| config_hash["approvals_labels_#{locale}"] = approvals_labels(locale) }
    config_hash
  end

  def config_object_names
    %w[SystemSettings]
  end
end
