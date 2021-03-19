# frozen_string_literal: true

# Anonymizes sensitive v1 record data
class DataAnonymizer
  # record_field_map is expected to contain implementation specific fields that need to be anonymized
  def initialize(record_types: %w[Case Incident TracingRequest],
                 record_field_map: {
                   case_fields: {},
                   incident_fields: {},
                   tracing_request_fields: {}
                 },
                 batch_size: 250)
    @record_types = record_types
    @record_field_map = record_field_map
    @batch_size = batch_size
  end

  def anonymize
    @record_types.each { |record_type| anonymize_records(record_type) }
  end

  private

  def model_class(record_type)
    record_type == 'Case' ? 'Child' : record_type
  end

  def sample_data_file_mapping
    {
      first_name: %w[db dev_fixtures names english_names.csv],
      last_name: %w[db dev_fixtures names english_surnames.csv],
      street_name: %w[db dev_fixtures locations english_street_names.csv],
      town_name: %w[db dev_fixtures locations english_town_names.csv]
    }
  end

  def sample_data(data_type)
    file = Rails.root.join(*sample_data_file_mapping[data_type.to_sym])
    CSV.read(file).flatten
  end

  def sample_first_names
    @sample_first_names ||= sample_data('first_name')
  end

  def sample_last_names
    @sample_last_names ||= sample_data('last_name')
  end

  def sample_street_names
    @sample_street_names ||= sample_data('street_name')
  end

  def sample_town_names
    @sample_town_names ||= sample_data('town_name')
  end

  def default_field_map_case
    {
      'name' => 'full_name',
      'name_first' => 'first_name',
      'name_middle' => 'first_name',
      'name_middle_other' => 'last_name',
      'name_last' => 'last_name',
      'name_nickname' => 'first_name',
      'name_other' => 'first_name',
      'name_caregiver' => 'full_name',
      'name_caregiver_closing' => 'full_name',
      'address_current' => 'address',
      'address_last' => 'address',
      'address_caregiver' => 'address',
      'address_caregiver_closing' => 'address',
      'address_caregiver_future' => 'address',
      'address_registration' => 'address',
      'location_registration' => 'address',
      'telephone_current' => 'phone',
      'telephone_last' => 'phone',
      'telephone_agency' => 'phone',
      'owned_by_phone' => 'phone',
      'telephone_caregiver' => 'phone',
      'telephone_caregiver_future' => 'phone'
    }
  end

  def default_field_map_incident
    {
      'caseworker_name' => 'full_name',
      'cp_incident_abuser_name' => 'full_name'
    }
  end

  def default_field_map_tracing_request
    {
      'caseworker_name' => 'full_name',
      'relation_name' => 'full_name',
      'relation_nickname' => 'first_name',
      'relation_address_current' => 'address',
      'address_separation' => 'address',
      'address_last' => 'address',
      'landmark_last' => 'address',
      'relation_telephone' => 'phone',
      'telephone_last' => 'phone'
    }
  end

  def field_map_case
    @field_map_case ||= default_field_map_case.merge(@record_field_map[:case_fields])
  end

  def field_map_incident
    @field_map_incident ||= default_field_map_incident.merge(@record_field_map[:incident_fields])
  end

  def field_map_tracing_request
    @field_map_tracing_request ||= default_field_map_tracing_request.merge(@record_field_map[:tracing_request_fields])
  end

  def field_map(record_type)
    send("field_map_#{record_type.underscore}")
  end

  def anonymize_address()
    "#{[*1..9999].sample} #{sample_street_names.sample} #{sample_town_names.sample}, XYZ"
  end

  # This is necessary to handle attributes on main level and on subforms
  def update_record(record, k, value, subform_index=0)
    keys = k.split('||')
    if keys.count == 1
      record[k] = value
    elsif keys.count == 2
      record[keys.first][subform_index][keys.last] = value
    end
  end

  def anonymize_subform(field_map, record, k, v)
    return unless v.is_a?(Array)

    v.each_with_index do |subform, index|
      subform.attributes.each do |sub_key, sub_value|
        subform_map_key = "#{k}||#{sub_key}"
        next if sub_value.blank? || field_map[subform_map_key].blank?

        anonymize_field(field_map, record, subform_map_key, sub_value, index)
      end
    end
  end

  def anonymize_field(field_map, record, k, v, subform_index=0)
    value = nil
    case field_map[k]
      when 'first_name'
        value = sample_first_names.sample
      when 'last_name'
        value = sample_last_names.sample
      when 'full_name'
        value = "#{sample_first_names.sample} #{sample_last_names.sample}"
      when 'address'
        value = anonymize_address
      when 'phone'
        value = "555-#{[*100..999].sample}-#{[*1000..9999].sample}"
      when 'subform'
        anonymize_subform(field_map, record, k, v)
      else
        #Do Nothing
    end
    update_record(record, k, value, subform_index) if value.present?
  end

  def anonymize_record(record, record_type)
    record.delete_photos(record.photo_keys)
    record.delete_audio

    field_map = field_map(record_type)
    return nil if field_map.blank?

    record.each do |k,v|
      next if v.blank? || field_map[k].blank?

      anonymize_field(field_map, record, k, v)
    end
    record
  end

  def anonymize_record_batch(record_batch, record_type)
    records_to_save = []
    record_batch.each do |record|
      records_to_save << anonymize_record(record, record_type)
    end
    return if records_to_save.blank?

    puts "Updating #{records_to_save.count} records"
    Object.const_get(model_class(record_type)).save_all!(records_to_save)
  end

  def anonymize_records(record_type)
    Object.const_get(model_class(record_type)).each_slice(@batch_size) do |record_batch|
      anonymize_record_batch(record_batch, record_type)
    end
  end
end