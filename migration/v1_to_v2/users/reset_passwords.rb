# frozen_string_literal: true

# Script to call Reset User Passwords
# Args:     send_emails - True/False  whether or not to send Welcome Email and Password Reset Email
#           password  - Default: sets random password
#
# Example:  $ rails r ./tmp/users/reset_passwords.rb 'true'
#               ** this resets to a randdom password and sends the reset password email ***
#
# Example:  $ rails r ./tmp/users/reset_passwords.rb 'false' 'test123'
#               ** this resets password to 'test123' and does not send the reset password email ***

@send_reset_email = ARGV[0] == 'true' || ARGV[0] == true
@password = ARGV[1].present? ? ARGV[1] : 'random'

User.all.each do |user|
  next if user.user_name == 'migration_system_user'

  puts "Resetting password for #{user.user_name}"
  if @password == 'random'
    user.generate_random_password
  else
    user.password = @password
    user.password_confirmation = @password
  end

  begin
    user.save!
    puts "updated"
    if @send_reset_email
      user.send_reset_password_instructions
    end
  rescue StandardError => e
    puts "Error #{e.message}"
  end
  puts '----------------------------------'
end