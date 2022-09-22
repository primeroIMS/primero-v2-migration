# frozen_string_literal: true

save_records = ARGV[0] || false
fields_to_evaluate = Field.eager_load(form_section: :subform_field).where(visible: true, type: Field::RADIO_BUTTON, option_strings_source: 'lookup lookup-yes-no')

# build structure of field
field_structure = fields_to_evaluate.each_with_object({}) do |ele, acc|
  acc[ele.form_section.parent_form] ||= { 'root' => [], 'subform' => {} }
  acc[ele.form_section.parent_form]['root'] << ele.name unless ele.form_section.is_nested
  if ele.form_section.is_nested
    acc[ele.form_section.parent_form]['subform'][ele.form_section.subform_field.name] ||= []
    acc[ele.form_section.parent_form]['subform'][ele.form_section.subform_field.name] << ele.name
  end
end

field_structure.each_key do |record_type|
  record_type_class = record_type == 'case' ? Child : record_type.camelize.constantize

  record_type_class.all.find_in_batches(batch_size: 10) do |records|
    records.each do |record|
      fields_updated = []
      field_structure[record_type]['root'].each do |field|
        next if record.data[field].nil? || ![true, false].include?(record.data[field])

        fields_updated << field
        record.data[field] = record.data[field].to_s
      end
      field_structure[record_type]['subform'].each do |key, values|
        next if record.data[key].nil? || !record.data[key].is_a?(Array)

        record.data[key].each_with_index do |_record_data_subform, idx|

          values.each do |subform_field|
            if record.data[key][idx][subform_field].nil? || ![true, false].include?(record.data[key][idx][subform_field])
              next
            end

            fields_updated << "#{key}-#{subform_field}"
            record.data[key][idx][subform_field] = record.data[key][idx][subform_field].to_s
          end
        end
      end

      next if fields_updated.blank? || !save_records

      puts "Updating #{record_type} #{record.short_id} - #{fields_updated.join(', ')}"

      record.update_column("data", record.data)
    end
  end
end
