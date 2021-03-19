# frozen_string_literal: true

# Script to call Data Anonymizer
require_relative('anonymizers/data_anonymizer.rb')

#TODO pass in implentation specific field mapping
data_anonymizer = DataAnonymizer.new(batch_size: 250)
data_anonymizer.anonymize