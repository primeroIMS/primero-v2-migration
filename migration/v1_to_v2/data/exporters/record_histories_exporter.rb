# frozen_string_literal: true

require_relative('data_exporter.rb')

# Generates a v2.0+ compatible script to create flags.
class RecordHistoriesExporter < DataExporter
  # rubocop:disable Style/StringLiterals

  HEADER = [
    "# Automatically generated script to migrate record histories from v1.7 to v2.0+\n",
    "histories = [\n"
  ].join("\n").freeze

  ENDING = [
    "]\n",
    "histories.each do |history|",
    "  puts \"Creating record history...\"",
    "  history.save!",
    "rescue ActiveRecord::RecordNotUnique",
    "  puts \"Skipping creation of history for \#{history.record_type} with id \#{history.record_id}. It already exists.\"",
    "rescue StandardError => e",
    "  puts \"Cannot create history for \#{history.record_type} with id \#{history.record_id} Error \#{e.message}\"",
    "  raise e",
    "end\n"
  ].join("\n").freeze

  # rubocop:enable Style/StringLiterals

  def initialize(options = {})
    super(options)
    @log = options[:log] || fallback_logger
  end

  def data_object_names
    %w[Case Incident TracingRequest]
  end

  private

  def fallback_logger
    timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
    log_filename = "histories-exporter-logs-#{timestamp}.txt"
    log = Logger.new(log_filename)
    log.formatter = proc do |severity, _, _, msg|
      "#{severity}: #{msg}\n"
    end
    log
  end

  def export_object_batch(object_name, objects, index)
    return if objects.blank?

    File.open(file_for(object_name, index), 'a') do |file|
      file.write(HEADER)
      objects.each { |object| write_record_histories(file, object) }
      file.write(ENDING)
    end
  end

  def file_for(_, index)
    config_dir = "#{@export_dir}/record_histories"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/record_history#{index}.rb"
  end

  def export_data_objects(object_name)
    puts 'Exporting record histories...'
    index = 0
    object_query(object_name).each_slice(@batch_size) do |objects|
      export_object_batch(object_name, objects, index)
      index += 1
    end
  end

  # rubocop:disable Style/RedundantBegin

  def write_record_histories(file, object)
    object.histories.each do |history|
      begin
        file.write(stringify_history(object, history))
        @log.info("History id: #{history.id} written successfully")
      rescue StandardError => e
        @log.error(e)
        @log.error("Error when History id #{history.id} was written")
      end
    end
  end

  # rubocop:enable Style/RedundantBegin

  # rubocop:disable Style/StringLiterals

  def stringify_history(object, history)
    [
      "  RecordHistory.new(",
      "    record_id: \"#{uuid_format(object.id)}\",",
      "    record_type: \"#{object.class.name}\",",
      "    datetime: DateTime.parse(\"#{history.datetime.strftime('%Y-%m-%dT%H:%M:%SZ')}\"),",
      "    user_name: \"#{history.user_name}\",",
      "    action: \"#{history.action}\",",
      "    record_changes: #{value_to_ruby_string(history.changes, true)}",
      "  ),\n"
    ].join("\n")
  end

  # rubocop:enable Style/StringLiterals
end
