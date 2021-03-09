# frozen_string_literal: true

require_relative('data_exporter.rb')

# Generates a v2.0+ compatible script to create alerts.
class AlertsExporter < DataExporter
  private

  def model_class(_record_type)
    'Alert'
  end

  def object_query(_object_name)
    Child
  end

  def data_object_names
    %w[Alert]
  end

  # rubocop:disable Style/StringLiterals

  def header
    [
      "# Automatically generated script to migrate alerts from v1.7 to v2.0+\n",
      "alerts = [\n"
    ].join("\n").freeze
  end

  def ending(_object_name)
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

  def object_hashes(_object_name, objects)
    objects.map do |object|
      next unless object.alerts.present? && object.alerts.is_a?(Array)

      object.alerts.map do |alert|
        alert_hash = alert.to_hash
        alert_hash['user'] = user_string(alert_hash)
        alert_hash['agency'] = agency_string(alert_hash)
        alert_hash['date'] = date_string(alert_hash)
        alert_hash['record_id'] = uuid_format(object.id)
        alert_hash['record_type'] = object.class.name
        alert_hash
      end
    end.compact.flatten
  end

  def date_string(object_hash)
    return unless object_hash['date'].present?

    "Date.parse(\"#{object_hash['date']}\")"
  end

  def user_string(object_hash)
    return unless object_hash['user'].present?

    "User.find_by(user_name: \"#{object_hash['user']}\"),"
  end

  def agency_string(object_hash)
    return unless object_hash['agency'].present?

    "Agency.find_by(unique_id: \"#{object_hash['agency']}\"),"
  end
end
