# frozen_string_literal: true

require_relative('data_exporter.rb')

# Generates a v2.0+ compatible script to create alerts.
class AlertsExporter < DataExporter
  def initialize(options = {})
    super(options)
    @log = options[:log] || fallback_logger
  end

  private

  # rubocop:disable Style/StringLiterals

  def header
    [
      "# Automatically generated script to migrate alerts from v1.7 to v2.0+\n",
      "alerts = [\n"
    ].join("\n").freeze
  end

  def ending(_)
    [
      "]\n",
      "alerts.each do |alert|",
      "  puts \"Creating record alert...\"",
      "  alert.save!",
      "rescue ActiveRecord::RecordNotUnique",
      "  puts \"Skipping creation of alert with id \#{alert.unique_id}. It already exists.\"",
      "rescue StandardError => e",
      "  puts \"Cannot create alert for alert with id \#{alert.unique_id}. Error \#{e.message}\"",
      "  raise e",
      "end\n"
    ].join("\n").freeze
  end

  # rubocop:enable Style/StringLiterals

  def file_for(_, index)
    config_dir = "#{@export_dir}/alerts"
    FileUtils.mkdir_p(config_dir)
    "#{config_dir}/alerts#{index}.rb"
  end

  def fallback_logger
    timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
    log_filename = "alerts-exporter-logs-#{timestamp}.txt"
    log = Logger.new(log_filename)
    log.formatter = proc do |severity, _, _, msg|
      "#{severity}: #{msg}\n"
    end
    log
  end

  def object_hashes(_, objects)
    hashes = objects.map do |object|
      object.alerts.map do |alert|
        alert_hash = alert.to_hash
        alert_hash['record_id'] = uuid_format(object.id)
        alert_hash['record_type'] = object.class.name
        alert_hash
      end
    end

    hashes.flatten
  end

  def export_data_objects(object_name)
    puts 'Exporting alerts...'
    super(object_name)
  end

  def data_object_names
    %w[Case]
  end

  # rubocop:disable Style/StringLiterals

  def config_to_ruby_string(object_hash, _)
    [
      "  Alert.new(",
      "    alert_for: \"#{object_hash['alert_for']}\",",
      "    type: \"#{object_hash['type']}\",",
      "    date: Date.parse(\"#{object_hash['date']}\"),",
      "    unique_id: \"#{object_hash['unique_id']}\",",
      "    form_sidebar_id: \"#{object_hash['form_sidebar_id']}\",",
      user_string(object_hash),
      agency_string(object_hash),
      "    record_id: \"#{object_hash['record_id']}\",",
      "    record_type: \"#{object_hash['record_type']}\"",
      "  ),\n"
    ].compact.join("\n")
  end

  def user_string(object_hash)
    return unless object_hash['user'].present?

    "    user: User.find_by(user_name: \"#{object_hash['user']}\"),"
  end

  def agency_string(object_hash)
    return unless object_hash['agency'].present?

    "    agency: Agency.find_by(unique_id: \"#{object_hash['agency']}\"),"
  end

  # rubocop:enable Style/StringLiterals
end
