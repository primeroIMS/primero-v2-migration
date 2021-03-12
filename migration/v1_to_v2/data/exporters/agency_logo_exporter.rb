# frozen_string_literal: true

require_relative('data_exporter.rb')

# Class that get agency's logo from v1.7 and generate files to be inserted on v2.x
class AgencyLogoExporter < DataExporter
  def initialize(export_dir: 'record-data-files', batch_size: 500)
    @export_dir = "#{export_dir}/agencies"
    super(export_dir: @export_dir, batch_size: batch_size)
  end

  private

  def data_object_names
    %w[Agency]
  end

  def object_hashes(_object_name, objects)
    objects
  end

  def export_object_batch(object_name, objects, index)
    create_file_to_export(object_name, index)
    objects.each do |object|
      export_object(object_name, object)
    end
  end

  def create_file_to_export(object_name, index)
    script_name = "#{object_name.downcase.pluralize}.#{index}.rb"
    @output_file = File.new("#{@export_dir}/#{script_name}", 'w')
    @output_file.puts(header)
    puts "Generating #{script_name}"
  end

  def export_object(_object_name, object)
    return if object['logo_key'].blank? || object['_attachments'].blank?

    puts "- Skipped logo for #{object['_id']}. Content-type is not image/png" unless logo_is_png?(object)
    return unless logo_is_png?(object)

    puts "- Exporting #{object['_id']} logo"
    build_logo_file(object)
    write_export_file(object)
  end

  def logo_is_png?(object)
    object['_attachments'][object['logo_key']]['content_type'] == 'image/png'
  end

  def build_logo_file(object)
    File.open("#{@export_dir}/#{object['logo_key']}", 'wb') do |f|
      f.write(object.fetch_attachment(object['logo_key']))
    end
  end

  def write_export_file(object)
    logo_path = "#{@export_dir}/#{object['logo_key']}"

    @output_file.puts "\nagency = Agency.find_by(unique_id: '#{object['_id']}')"
    @output_file.puts "logo = { io: File.open('#{logo_path}'), filename: '#{object['logo_key']}' }"
    @output_file.puts "puts 'Adding logo to #{object['_id']}'"
    @output_file.puts 'agency.logo_full.attach(logo)'
    @output_file.puts 'agency.save!'
  end

  def header
    ["# frozen_string_literal: true\n",
     "# Automatically generated script to migrate agency logo from v1.7 to v2.0+\n"].join("\n")
  end
end
