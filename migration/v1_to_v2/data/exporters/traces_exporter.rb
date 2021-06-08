# frozen_string_literal: true

require_relative('data_exporter.rb')

# Generates a v2.0+ compatible script to create traces.
class TracesExporter < DataExporter
  private

  def model_class(_object_name)
    'Trace'
  end

  def object_query(_object_name)
    TracingRequest
  end

  def data_object_names
    %w[Trace]
  end

  # rubocop:disable Style/StringLiterals

  def header
    [
      "# Automatically generated script to migrate traces from v1.7 to v2.0+\n",
      "traces = [\n"
    ].join("\n").freeze
  end

  def ending(_)
    [
      "]\n",
      "traces.each do |trace|",
      "  puts \"Creating Trace...\"",
      "  flag.save!",
      "rescue ActiveRecord::RecordNotUnique",
      "  puts \"Skipping creation of trace with id \#{trace.record_id}. It already exists.\"",
      "rescue StandardError => e",
      "  puts \"Cannot create trace with id \#{trace.record_id} Error \#{e.message}\"",
      "  raise e",
      "end\n"
    ].join("\n").freeze
  end

  # rubocop:enable Style/StringLiterals

  def object_data_hash(object)
    object.tracing_request_subform_section.map do |trace|
      # TODO - WIP
      trace_hash = {}
      trace_hash['id'] = 'xxx'
      trace_hash['tracing_request_id'] = 'xxx'
      trace_hash['matched_case_id'] = 'xxx'
      trace_hash['data'] = {}

      trace_hash = trace.to_hash
      # alert_hash['user'] = user_string(alert_hash)
      # alert_hash['agency'] = agency_string(alert_hash)
      # alert_hash['date'] = date_string(alert_hash)
      # alert_hash['record_id'] = uuid_format(object.id)
      # alert_hash['record_type'] = object.class.name
      # handle_incident_from_case_alert(alert_hash)
    end
  end

  def object_hashes(_object_name, objects)
    objects.map do |object|
      next unless object.tracing_request_subform_section.present? && object.tracing_request_subform_section.is_a?(Array)

      object_data_hash(object)
    end.compact.flatten
  end
end