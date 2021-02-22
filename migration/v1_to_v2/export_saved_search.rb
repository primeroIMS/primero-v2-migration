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

def write_saved_search(file, saved_search)
  saved_search_hash = [
    "  SavedSearch.new_with_user(",
    "    User.find_by(user_name: \"#{saved_search.user_name}\"),",
    "    { ",
    "      record_type: \"#{saved_search.record_type}\",",
    "      filters: #{saved_search.filters.as_json},",
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
