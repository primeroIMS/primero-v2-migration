# frozen_string_literal: true

require_relative('data_exporter.rb')

# Exports v1 Primero transitions that are linked to records as v2 compatible ruby script files.
class TransitionDataExporter < DataExporter
  TRANSITION_TYPE_MAPPING = {
    'reassign' => 'Assign',
    'referral' => 'Referral',
    'transfer' => 'Transfer'
  }.freeze

  private

  def model_class(record_type)
    new_type = record_type.dup
    new_type.slice!('Transition')
    new_type == 'Case' ? 'Child' : new_type
  end

  def model_class_for_insert(_record_type)
    'Transition'
  end

  def new_string(_record_type)
    'Transition.new'
  end

  def data_hash_transition(object, data_hash)
    keys = data_hash.keys
    data_hash.delete('unique_id')
    data_hash['record_id'] = uuid_format(object.id)
    data_hash['record_type'] = object.class.name
    data_hash['type'] = TRANSITION_TYPE_MAPPING[data_hash['type']]
    data_hash['transitioned_to'] = data_hash.delete('to_user_local') if keys.include?('to_user_local')
    data_hash['transitioned_to_remote'] = data_hash.delete('to_user_remote') if keys.include?('to_user_remote')
    data_hash['transitioned_to_agency'] = data_hash.delete('to_user_agency') if keys.include?('to_user_agency')
    data_hash['status'] = data_hash.delete('to_user_local_status') if keys.include?('to_user_local_status')
    data_hash['service_record_id'] = data_hash.delete('service_section_unique_id') if keys.include?('service_section_unique_id')
    data_hash['remote'] = data_hash.delete('is_remote') if keys.include?('is_remote')
    data_hash['rejection_note'] = data_hash.delete('note_on_referral_from_provider') if keys.include?('note_on_referral_from_provider')
    data_hash
  end

  def object_hashes(_object_name, objects)
    objects.select { |object| object.transitions.present? }.map do |object|
      next unless object.transitions.is_a?(Array)

      object.transitions.reverse.map { |transition| data_hash_transition(object, parse_object(transition)) }
    end.flatten
  end

  def data_object_names
    %w[CaseTransition IncidentTransition TracingRequestTransition]
  end
end
