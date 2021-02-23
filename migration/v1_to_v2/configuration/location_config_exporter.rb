class LocationConfigExporter
  def initialize(options = {})
    @export_dir = options[:export_dir] || 'seed-files'
    @config_dir = "#{@export_dir}/locations"
    @config_file = "#{@config_dir}/locations.rb"
    @batch_size = options[:batch_size] || 500
    @log = options[:log] || fallback_logger
  end

  def export
    FileUtils.mkdir_p(@config_dir)
    File.open(File.expand_path(@config_file), 'a+') do |file|
      write_header(file)
      Location.by_admin_level.each_slice(@batch_size) do |batch|
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

  private

  def fallback_logger
    timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
    log_filename = "location-config-exporter-logs-#{timestamp}.txt"
    log = Logger.new(log_filename)
    log.formatter = proc do |severity, datetime, progname, msg|
      "#{severity}: #{msg}\n"
    end
    log
  end

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
    ruby_string += "),\n"
  
    ruby_string
  end
  
  def write_location(file, location)
    file.write(stringify_location(location))
  end
  
  def write_header(file)
    header = [
      "# Automatically generated script to migrate locations from v1.7 to v2.0+\n",
      "Location.destroy_all\n",
      "locations = [\n"
    ].join("\n")
  
    file.write(header)
  end
  
  def write_end(file)
    ending =[
      "]\n",
      "Location.locations_by_code = locations.map { |l| [l.location_code, l] }.to_h\n",
      "locations.each do |loc|",
      "  loc.set_name_from_hierarchy_placenames",
      "end\n",
      "locations.each(&:save!)\n"
    ].join("\n")
  
    file.write(ending)
  end
end
