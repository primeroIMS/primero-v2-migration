# frozen_string_literal: true

# Generates a v2.0+ compatible script to create saved searches.
class SavedSearchesExporter
  # rubocop:disable Style/StringLiterals, Style/RedundantBegin

  RECORD_TYPE_MAPPING = {
    "child" => "cases",
    "incident" => "incidents"
  }.freeze

  HEADER = [
    "# Automatically generated script to migrate saved searches from v1.7 to v2.0+\n",
    "puts 'Deleting all saved searches...'",
    "SavedSearch.destroy_all\n",
    "saved_searches = [\n"
  ].join("\n")

  ENDING = [
    "]\n",
    "saved_searches.each do |saved_search|",
    "  begin",
    "    saved_search.save!",
    "    puts \"SavedSearch created successfuly for user: \#{saved_search.user.user_name}\"",
    "  rescue StandardError => e",
    "    puts 'Error creating saved search'",
    "    puts e",
    "  end",
    "end\n"
  ].join("\n")

  def initialize(options = {})
    @export_dir = options[:export_dir] || 'seed-files'
    @config_dir = "#{@export_dir}/users"
    @config_file = "#{@config_dir}/saved_searches.rb"
    @batch_size = options[:batch_size] || 500
    @log = options[:log] || fallback_logger
  end

  def export
    config_dir = "#{@export_dir}/users/"
    FileUtils.mkdir_p(config_dir)
    File.open(File.expand_path(@config_file), 'a+') do |file|
      file.write(HEADER)
      SavedSearch.each_slice(@batch_size) { |batch| write_batch(file, batch) }
      file.write(ENDING)
    end
  end

  private

  def fallback_logger
    timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
    log_filename = "saved-searches-exporter-logs-#{timestamp}.txt"
    log = Logger.new(log_filename)
    log.formatter = proc do |severity, _, _, msg|
      "#{severity}: #{msg}\n"
    end
    log
  end

  def write_batch(file, batch)
    batch.each do |saved_search|
      begin
        file.write(stringify_saved_search(saved_search))
        @log.info("SavedSearch | user_name: #{saved_search.user_name} written successfully")
      rescue StandardError => e
        @log.error(e)
        @log.error("Error when user_name: #{saved_search.user_name} was written")
      end
    end
  end

  def stringify_saved_search(saved_search)
    [
      "  SavedSearch.new_with_user(",
      "    User.find_by(user_name: \"#{saved_search.user_name}\"),",
      "    { ",
      "      record_type: \"#{RECORD_TYPE_MAPPING[saved_search.record_type]}\",",
      "      filters: #{convert_filters(saved_search.filters)},",
      "      module_id: #{saved_search.module_id},",
      "      name: \"#{saved_search.name}\"",
      "    }",
      "  ),\n"
    ].join("\n")
  end

  def convert_filters(filters)
    filters.map do |filter|
      filter_value = filter["value"]
      next(filter.merge(convert_hash_value(filter_value))) if filter_value.is_a?(Hash)

      value = convert_array_value(filter_value)
      filter.merge("value" => value)
    end
  end

  def convert_array_value(filter_value)
    case filter_value.first
    when "list" then [filter_value.last]
    when "range" then [filter_value.last.split("-").map(&:strip).join("..")]
    when "date_range"
      dates = filter_value.last.split(".").map do |date|
        DateTime.parse(date).utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      end

      [dates.join("..")]
    when "location" then [filter_value.last]
    when "single" then ["true"]
    else
      filter_value
    end
  end

  def convert_hash_value(filter_value)
    if filter_value.values.flatten.first == "or_op"
      { 'name' => 'or', 'value' => { filter_value.keys.first => filter_value.values.flatten.last } }
    else
      filter_value
    end
  end

  # rubocop:enable Style/StringLiterals, Style/RedundantBegin
end
