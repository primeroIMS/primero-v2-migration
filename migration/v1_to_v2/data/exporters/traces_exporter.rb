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
      "  trace.save!",
      "rescue ActiveRecord::RecordNotUnique",
      "  puts \"Skipping creation of trace with id \#{trace.id}. It already exists.\"",
      "rescue StandardError => e",
      "  puts \"Cannot create trace with id \#{trace.id} Error \#{e.message}\"",
      "  raise e",
      "end\n"
    ].join("\n").freeze
  end

  # rubocop:enable Style/StringLiterals

  def object_data_hash(object)
    object.tracing_request_subform_section.map do |trace|
      trace_hash = {}
      trace_hash['id'] = trace.unique_id
      trace_hash['tracing_request_id'] = uuid_format(object.id)
      trace_hash['matched_case_id'] = uuid_format(trace.matched_case_id)
      trace_data = trace.to_hash.except('matched_case_id')
      trace_hash['data'] = parse_object(trace_data)
      trace_hash
    end
  end

  def object_hashes(_object_name, objects)
    objects.map do |object|
      next unless object.tracing_request_subform_section.present? && object.tracing_request_subform_section.is_a?(Array)

      object_data_hash(object)
    end.compact.flatten
  end
end