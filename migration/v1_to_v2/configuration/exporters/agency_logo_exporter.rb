# frozen_string_literal: true

require_relative('configuration_exporter.rb')

# Class that get agency's logo from v1.7 and generate files to be inserted on v2.x
class AgencyLogoExporter < ConfigurationExporter
  def initialize(export_dir: 'seed-files', batch_size: 500)
    @export_dir = "#{export_dir}/agency_logos"
    @batch_size = batch_size
    super(export_dir: @export_dir)
  end

  private

  def config_object_names
    %w[Agency]
  end

  def config_objects(config_name)
    Object.const_get(config_name)
  end

  def export_config_objects(config_name, config_class)
    export_data_objects(config_name, config_class)
  end

  def export_data_objects(object_name, config_class)
    config_class.each_slice(@batch_size) do |objects|
      export_object_batch(object_name, objects, @indent)
      _i
    end
  end

  def export_object_batch(object_name, objects, index)
    objects.each do |object|
      next if object['logo_key'].blank? || object['_attachments'].blank?

      puts "- Skipped logo for #{object['_id']}. Content-type is not image/png" unless logo_is_png?(object)
      next unless logo_is_png?(object)

      create_file_to_export(object_name, index)
      export_object(object_name, object)
    end
  end

  def create_file_to_export(object_name, index)
    script_name = "#{object_name.downcase.pluralize}.#{index}.rb"
    @output_file = File.open("#{@export_dir}/#{script_name}", 'a')
  end

  def export_object(_object_name, object)
    puts "- Exporting #{object['_id']} logo"
    build_logo_file(object)
    write_export_file(object)
  end

  def logo_is_png?(object)
    object['_attachments'][object['logo_key']]['content_type'] == 'image/png'
  end

  def build_logo_file(object)
    logo_name = "#{object['_id']}-#{object['logo_key']}"
    File.open("#{@export_dir}/#{logo_name}", 'wb') do |f|
      f.write(object.fetch_attachment(object['logo_key']))
    end
  end

  def write_export_file(object)
    logo_name = "#{object['_id']}-#{object['logo_key']}"
    @output_file.puts "\nagency = Agency.find_by(unique_id: '#{object['_id']}')"
    @output_file.puts "logo_full = { io: File.open(\"\#{File.dirname(__FILE__)}/#{logo_name}\"), filename: '#{object['logo_key']}' }"
    @output_file.puts "logo_icon = { io: File.open(\"\#{File.dirname(__FILE__)}/#{logo_name}\"), filename: '#{object['logo_key']}' }"
    @output_file.puts "puts 'Adding logo to #{object['_id']}'"
    @output_file.puts 'agency.logo_full.attach(logo_full)'
    @output_file.puts 'agency.logo_icon.attach(logo_icon)'
    @output_file.puts 'agency.save!'
  end
end
