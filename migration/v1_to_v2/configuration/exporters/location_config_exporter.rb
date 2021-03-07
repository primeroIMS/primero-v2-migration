# frozen_string_literal: true

# Generates a v2.0+ compatible script to create locations.
class LocationConfigExporter
  # rubocop:disable Style/StringLiterals

  HEADER = [
    "# Automatically generated script to migrate locations from v1.7 to v2.0+\n",
    "Location.destroy_all\n",
    "locations = [\n"
  ].join("\n").freeze

  ENDING = [
    "]\n",
    "Location.locations_by_code = locations.map { |l| [l.location_code, l] }.to_h\n",
    "locations.each do |loc|",
    "  loc.set_name_from_hierarchy_placenames",
    "end\n",
    "locations.each do |loc|",
    "  puts \"Creating location \#{loc.location_code}\"",
    "  loc.save!",
    "rescue ActiveRecord::RecordNotUnique",
    "  puts \"Skipping. Location \#{loc.location_code} already exists!\"",
    "rescue StandardError => e",
    "  puts \"Cannot create \#{loc.location_code}. Error \#{e.message}\"",
    "  raise e",
    "end\n"
  ].join("\n").freeze

  # rubocop:enable Style/StringLiterals

  def initialize(options = {})
    @export_dir = options[:export_dir] || 'seed-files'
    @config_dir = "#{@export_dir}/locations"
    @config_file = "#{@config_dir}/locations.rb"
    @batch_size = options[:batch_size] || 500
    @log = options[:log] || fallback_logger
  end

  def export
    puts 'Exporting Locations'
    FileUtils.mkdir_p(@config_dir)
    File.open(File.expand_path(@config_file), 'a+') do |file|
      begin
        file.write(HEADER)
        Location.by_admin_level.each_slice(@batch_size) { |batch| write_batch(file, batch) }
        file.write(ENDING)
      rescue StandardError => e
        @log.error(e)
      end
    end
  end

  private

  def write_batch(file, batch)
    batch.each do |location|
      begin
        file.write(stringify_location(location))
        @log.info("location code #{location.location_code} written successfully")
      rescue StandardError => e
        @log.error(e)
        @log.error("Error when location code #{location.location_code} was written")
      end
    end
  end

  def fallback_logger
    timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
    log_filename = "location-config-exporter-logs-#{timestamp}.txt"
    log = Logger.new(log_filename)
    log.formatter = proc do |severity, _, _, msg|
      "#{severity}: #{msg}\n"
    end
    log
  end

  def stringify_location(location)
    ruby_string = '  Location.new('

    ruby_string += build_placename(location)
    ruby_string += "location_code:\"#{location['location_code']}\", "
    ruby_string += "admin_level: #{location['admin_level'] || 'nil'}, "
    ruby_string += "type: \"#{location['type']}\", "
    ruby_string += "hierarchy_path: '#{build_hierarchy_path(location)}'"
    ruby_string += "),\n"

    ruby_string
  end

  def build_placename(location)
    placename = 'placename_i18n: { '

    I18n.available_locales.map do |locale|
      placename_value = location["placename_#{locale}"]
      placename += ', ' unless locale == I18n.available_locales.first || placename_value.blank?
      next if placename_value.blank?

      placename += "\"#{locale}\": \"#{placename_value}\""
    end

    placename += ' }, '

    placename
  end

  def build_hierarchy_path(location)
    (location['hierarchy'] + [location['location_code']]).join('.')
  end
end
