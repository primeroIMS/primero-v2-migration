# frozen_string_literal: true

require 'csv'

# Run this script in v1 to find users that will not be valid in v2
# Creates a csv file for..
# -  users with multiple roles
# -  users with blank or bogus roles
# -  users with no location
# -  users with blank or bogus user_group_ids
# -  users with no email
# -  users with duplicate emails
# -  users that are disabled  (These users aren't a problem, it will be used later when re-enabling users in v2)
#
# To execute this script:
#    rails r <path>/users/invalid_users_report.rb
def user_log(log_name)
  timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
  "#{log_name}-#{timestamp}.csv"
end

def write_log(users, log_name)
  return if users.blank?

  CSV.open(user_log(log_name), "w") do |csv|
    csv << ['User Name', 'Role IDs', 'Agency ID', 'User Group IDs', 'Email']
    users.each do |user|
      csv << [user.user_name, user.role_ids, user.organization, user.user_group_ids, user.email]
    end
  end
end

user_multiple_roles = []
user_bad_role = []
user_no_location = []
user_bad_user_group = []
user_no_agency = []
user_no_email = []
user_disabled = []

user_group_ids = UserGroup.all.map(&:id)
role_ids = Role.all.map(&:id)

User.all.each do |user|
  user_multiple_roles << user if user.role_ids.count > 1
  user_bad_role << user if user.role_ids.blank? || user.role_ids.any?{|id| role_ids.exclude?(id)}
  user_no_agency << user if user.agency.blank?
  user_no_location << user if user.location.blank?
  user_no_email << user if user.email.blank?
  user_bad_user_group << user if user.user_group_ids.any?{|ug| ug.blank? || user_group_ids.exclude?(ug)}
  user_disabled << user if user.disabled
end

dupe_emails = User.all.group_by(&:email).select {|k, v| k.present? && v.count > 1}

write_log(user_multiple_roles, 'user-multiple-roles')
write_log(user_bad_role, 'user-bad-role')
write_log(user_no_agency, 'user-no-agency')
write_log(user_no_location, 'user-no-location')
write_log(user_bad_user_group, 'user-bad-user-group')
write_log(user_no_email, 'user-no-email')
write_log(dupe_emails.values.flatten, 'user-duplicate-email')
write_log(user_disabled, 'user-disabled')
