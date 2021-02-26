# frozen_string_literal: true

require 'fileutils'

# rubocop:disable Metrics/ClassLength
# Class that get record's attachments and generate files to be inserted
class AttachmentExporter
  RECORD_TYPES = {
    'case' => 'Child',
    'incident' => 'Incident',
    'tracing_request' => 'TracingRequest'
  }.freeze

  ATTACHMENTS_FORMS = {
    'case' => %w[photo_keys bia_documents bid_documents other_documents],
    'incident' => [],
    'tracing_request' => []
  }.freeze

  FIELD_MAPPING = {
    'audio_attachments' => 'recorded_audio',
    'photo_keys' => 'current_photo_key',
    'bia_documents' => 'upload_bia_document',
    'bid_documents' => 'upload_bid_document',
    'other_documents' => 'other_documents'
  }.freeze

  def initialize(options = {})
    @export_dir = options[:base_folder] || 'record-data-files'
    @batch_size = options[:batch_size] || 500
    @json_to_export = {}
    FileUtils.mkdir_p(@export_dir)
  end

  def export
    ATTACHMENTS_FORMS.each do |type, forms|
      @record_type = RECORD_TYPES[type].constantize

      next if forms.empty? || @record_type.count.zero?

      type_folder = "#{type.pluralize}-attachments"
      folder_to_save = "#{@export_dir}/#{type_folder}"

      FileUtils.mkdir_p(folder_to_save)

      puts "Exporting #{@record_type.count} #{type.pluralize}"
      export_records(forms, type, folder_to_save)
    end
  end

  private

  def uuid_format(old_id)
    [old_id[0..7], old_id[8..11], old_id[12..15], old_id[16..19], old_id[20..31]].join('-')
  end

  def set_record_id(type, record_id)
    @record_id = uuid_format(record_id)
    @json_to_export[type][@record_id] = {}
  end

  def export_records(forms, type, folder_to_save)
    sufix = 0
    @record_type.each_slice(@batch_size) do |records|
      @json_to_export[type] = {}
      records.each do |record|
        next if record&._attachments&.empty?

        set_record_id(type, record._id)
        export_forms_attachments(forms, record, folder_to_save, type)
      end
      build_file(folder_to_save, type, sufix += 1)
    end
  end

  def export_forms_attachments(forms, record, folder_to_save, type)
    forms.each do |form|
      files = get_files_to_export(record.send(form), form)

      next if files.empty?

      puts "Exporting #{form} from #{type} - #{@record_id}"
      build_data_to_attach(files, folder_to_save, type, form)
      export_file(files, folder_to_save, record, form)
    end
  end

  def get_files_to_export(files, form)
    return [] if files.empty?

    return { files.values.last => "#{files.values.last}.#{files.keys.last}" } if form == 'audio_attachments'
    return files.reduce({}) { |acc, doc| acc.merge(doc => doc) } if form == 'photo_keys'

    files.reduce({}) { |acc, doc| acc.merge(doc.attachment_key => doc) }
  end

  def build_data_to_attach(files, folder, type, form)
    @json_to_export[type][@record_id][form] = []
    files.each do |_key, value|
      name = value.is_a?(String) ? value : value.file_name

      @json_to_export[type][@record_id][form] << {
        record_type: @record_type.to_s, record_id: @record_id, field_name: form,
        file_name: name, date: value.try(:date), comments: value.try(:comments),
        is_current: value.try(:is_current) || false, description: value.try(:document_description),
        path: "#{folder}/#{@record_id}/#{form}/#{name}"
      }
    end
  end

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

  def get_field_name(attachement_form)
    FIELD_MAPPING[attachement_form]
  end

  def mime_type(path)
    `file --brief --mime-type #{path}`.strip
  end

  def get_attachment_type(path)
    mime = mime_type(path)
    return 'audio' if mime.start_with?('audio')
    return 'image' if mime.start_with?('image')

    'document'
  end

  def initialize_script_for_attachment(folder_to_save, type, sufix)
    script_name = "#{type.pluralize}.#{sufix}.rb"
    @output = File.new("#{folder_to_save}/#{script_name}", 'w')
    @output.puts("# Automatically generated script to migrate attachment from v1.7 to v2.0+\n\n")
    puts "Generating #{script_name} for #{type} - #{@record_id}"
  end

  def add_attachment_type_to_file_for_attachment(path)
    @output.puts "attachement.attachment_type = '#{get_attachment_type(path)}'"
  end

  def add_date_to_file_for_attachment(date)
    return unless date.present?

    @output.puts "attachement.date = \"#{date.strftime('%Y-%m-%d')}\""
  end

  def write_script_for_attachment(form_name, files)
    files.each do |data|
      @output.puts "puts 'Inserting \"#{get_attachment_type(data[:path])}\" to #{data[:record_id]}'"
      @output.puts "attachement = Attachment.new(#{data.except(:path, :field_name, :date)})"
      add_date_to_file_for_attachment(data[:date])
      @output.puts "attachement.record_type = #{data[:record_type]}"
      add_attachment_type_to_file_for_attachment(data[:path])
      @output.puts "attachement.field_name = '#{get_field_name(form_name)}'"
      @output.puts "attachement.file.attach(io: File.open('#{data[:path]}'), filename: '#{data[:file_name]}')"
      @output.puts "attachement.save!\n\n\n"
    end
  end

  def build_file(folder_to_save, type, sufix)
    initialize_script_for_attachment(folder_to_save, type, sufix)
    RECORD_TYPES.keys.each do |key|
      next if @json_to_export[key].blank?

      @json_to_export[key].values.each do |value|
        value.each do |form_name, files|
          write_script_for_attachment(form_name, files)
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
