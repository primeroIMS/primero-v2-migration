puts 'Generating location migration script...'

def build_placename(location)
  placename = "placename_i18n: { "

  I18n.available_locales.map do |locale|
   placename_value = location["placename_#{locale.to_s}"]
   placename += ", " unless (locale == I18n.available_locales.first || placename_value.blank?)
   next if placename_value.blank?

   placename += "\"#{locale.to_s}\": \"#{placename_value}\""
  end

  placename += " }, "

  placename
end

def stringify_location(location)
  ruby_string = '  Location.new('

  ruby_string += build_placename(location)

  ruby_string += "location_code:\"#{location['location_code']}\", "
  ruby_string += "admin_level: #{location['admin_level'] || 'nil'}, "
  ruby_string += "type: \"#{location['type']}\", "
  ruby_string += "hierarchy_path: '#{(location['hierarchy'] + [location['location_code']]).join('.')}'"
  ruby_string += "), \n"

  ruby_string
end

def write_location(file, location)
  file.write(stringify_location(location))
end

def write_header(file)
  header = "# Automatically generated script to migrate locations from v1.7 to v2.0+\n\n" 
  header += "Location.destroy_all\n\n"
  header += "locations = [\n"

  file.write(header)
end

def write_end(file)
  ending = "]\n\n"
  ending += "Location.locations_by_code = locations.map { |l| [l.location_code, l] }.to_h\n\n"
  ending += "locations.each do |loc|\n"
  ending += "  loc.set_name_from_hierarchy_placenames\n"
  ending += "end\n\n"
  ending += "locations.each(&:save!)\n"

  file.write(ending)
end

def build_locations
  config_dir = "#{@export_dir}/locations"
  FileUtils.mkdir_p(config_dir)
  File.open(File.expand_path("#{config_dir}/locations.rb"), 'a+') do |file|
    write_header(file)
    Location.by_admin_level.each_slice(500) do |batch|
      batch.each do |location|
        begin
          write_location(file, location)
          @log.info("location code #{location.location_code} written successfully")
        rescue StandardError => e
          @log.error(e)
          @log.error("Error when location code #{location.location_code} was written")
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
log_filename = "migrate-location-logs-#{timestamp}.txt"
@log = Logger.new(log_filename)
@log.formatter = proc do |severity, datetime, progname, msg|
  "#{severity}: #{msg}\n"
end

build_locations
