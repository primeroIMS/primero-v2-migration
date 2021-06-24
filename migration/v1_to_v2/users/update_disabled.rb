# frozen_string_literal: true

# Script to update User disabled to true or false
# Args:     disabled - True/False
#           users_to_skip  - List of user_names to skip. These user_names are separated by ||
#
# Example:  $ rails r ./tmp/users/update_disabled.rb 'true'
#               ** this resets all users to disabled ***
#
# Example:  $ rails r ./tmp/users/update_disabled.rb 'false' 'primero||primero_cp||primero_mgr_cp'
#               ** this resets all users to enabled (disabled = false) except primero, primero_cp, and primero_mgr_cp ***

@disabled = ARGV[0] == 'true' || ARGV[0] == true
@users_to_skip = ARGV[1].present? ? ARGV[1].split('||') : []

User.all.each do |user|
  next if @users_to_skip.include?(user.user_name)

  puts "Resetting disabled for #{user.user_name} to value #{@disabled}"
  user.disabled = @disabled

  begin
    user.save!
    puts "updated"
  rescue StandardError => e
    puts "Error #{e.message}"
  end
  puts '----------------------------------'
end