# frozen_string_literal: true

puts 'Exporting Base Configuration Files'
require File.join(Rails.root, File.dirname(__FILE__) + '/exporters/ruby_config_exporter.rb')
ruby_config_exporter = RubyConfigExporter.new
ruby_config_exporter.export