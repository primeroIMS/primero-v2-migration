puts 'Exporting saved searches...'

def write_header(file)
  header = [
    "# Automatically generated script to migrate saved searches from v1.7 to v2.0+\n",
    "#####################",
    "# BEGINNING OF SCRIPT",
    "#####################\n",
    "puts 'Migrating saved searches...'\n",
  ].join("\n")

  file.write(header)
end

def write_initializers(file)
  initializers = [
    "timestamp = DateTime.now.strftime('%Y%m%d.%I%M')",
    "log_filename = \"create-saved-searches-logs-\#{timestamp}.txt\"",
    "@log = Logger.new(log_filename)",
    "@log.formatter = proc do |severity, datetime, progname, msg|",
    "  \"\#{severity}: \#{msg}\\n\"",
    "end\n",
    "saved_searches = [\n"
  ].join("\n")

  file.write(initializers)
end

@record_type_mapping = {
  "child" => "cases",
  "incident" => "incidents"
}

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
    { name: "or", value: { [filter_value.keys.first] => filter_value.values.flatten.last } }
  else
    filter_value
  end
end

def to_v2_filters(filters)
  filters.map do |filter|
    filter_value = filter["value"]
    next(filter.merge(convert_hash_value(filter_value))) if filter_value.is_a?(Hash)

    value = convert_array_value(filter_value)
    filter.merge({ "value" => value })
  end
end

def write_saved_search(file, saved_search)
  saved_search_hash = [
    "  SavedSearch.new_with_user(",
    "    User.find_by(user_name: \"#{saved_search.user_name}\"),",
    "    { ",
    "      record_type: \"#{@record_type_mapping[saved_search.record_type]}\",",
    "      filters: #{to_v2_filters(saved_search.filters)},",
    "      module_id: #{saved_search.module_id},",
    "      name: \"#{saved_search.name}\"",
    "    }",
    "  ),\n"
  ].join("\n")

  file.write(saved_search_hash)
end

def write_end(file)
  ending = [
    "\n]\n",
    "saved_searches.each do |saved_search|",
    "  begin",
    "    saved_search.save!",
    "  rescue StandardError => e",
    "    @log.error(e)",
    "  end",
    "end\n"
  ].join("\n")

  file.write(ending)
end

def export_saved_searches
  config_dir = "#{@export_dir}/users/"
  FileUtils.mkdir_p(config_dir)
  File.open(File.expand_path("#{config_dir}/saved_searches.rb"), 'a+') do |file|
    write_header(file)
    write_initializers(file)
    SavedSearch.each_slice(500) do |batch|
      batch.each do |saved_search|
        begin
          write_saved_search(file, saved_search)
          @log.info("SavedSearch | user_name: #{saved_search.user_name} written successfully")
        rescue StandardError => e
          @log.error(e)
          @log.error("Error when user_name: #{saved_search.user_name} was written")
        end
      end
    end
    write_end(file)
  end
end

#####################
# BEGINNING OF SCRIPT
#####################
@export_dir = 'seed-files'
FileUtils.mkdir_p(@export_dir)

timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
log_filename = "export-saved-searches-logs-#{timestamp}.txt"
@log = Logger.new(log_filename)
@log.formatter = proc do |severity, datetime, progname, msg|
  "#{severity}: #{msg}\n"
end

export_saved_searches
