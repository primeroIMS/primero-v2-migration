# frozen_string_literal: true

require 'fileutils'

def export_file(files, folder, record_data, form)
  files.each do |key, value|
    name = value.is_a?(String) ? value : value.file_name
    path_folder = "#{folder}/#{@record_id}/#{form}"

    FileUtils.mkdir_p(path_folder)
    File.open("#{path_folder}/#{name}", 'wb') do |f|
      f.write(record_data.fetch_attachment(key))
    end
  end
end

def build_data_to_json(files, folder, form)
  # binding.pry
  @json_to_export[@record_type.to_s][@record_id][form] = [] if files.present?
  files.each do |key, value|
    name = value.is_a?(String) ? value : value.file_name
    path_folder = "#{folder}/#{@record_id}/#{form}"

    @json_to_export[@record_type.to_s][@record_id][form] << {
      id: key,
      filename: name,
      path: "#{path_folder}/#{name}"
    }
  end
end

def get_files_to_export(files, form)
  return [] if files.empty?

  return { files.values.last => "#{files.values.last}.#{files.keys.last}" } if form == 'audio_attachments'
  return files.reduce({}) { |acc, doc| acc.merge(doc => doc) } if form == 'photo_keys'

  files.reduce({}) { |acc, doc| acc.merge(doc.attachment_key => doc) }
end

BASE_FOLDER = ARGV[0] || 'files-to-export'
ATTACHMENTS_FORMS = {
  'Child' => %w[audio_attachments photo_keys bia_documents bid_documents other_documents],
  'Incident' => [],
  'TracingRequest' => []
}.freeze

FileUtils.mkdir_p(BASE_FOLDER)
ATTACHMENTS_FORMS.each do |type, forms|
  @record_type = type.constantize
  @json_to_export = {}

  next if forms.empty? || @record_type.count.zero?

  folder_to_save = "#{BASE_FOLDER}/#{type}"

  FileUtils.mkdir_p(folder_to_save)

  @json_to_export[type] = {}

  puts "Importing #{@record_type.count} #{type.pluralize}"
  @record_type.each_slice(100) do |records|
    records.each do |record|
      next if record&._attachments&.empty?

      @record_id = record._id
      @json_to_export[type][@record_id] = {}
      # binding.pry

      forms.each do |form|
        files_data = record.send(form)
        files = get_files_to_export(files_data, form)

        build_data_to_json(files, folder_to_save, form)

        export_file(files, folder_to_save, record, form)
      end
    end
  end

  File.open("#{BASE_FOLDER}/#{type}.#{DateTime.now.strftime('%Y%m%d.%H%M')}.json", 'w') do |f|
    f.write(JSON.pretty_generate(@json_to_export))
  end

end
