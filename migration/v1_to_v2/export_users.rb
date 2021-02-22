# Export users

puts 'Exporting users...'

def write_header(file)
  header = [
    "# Automatically generated script to migrate users from v1.7 to v2.0+\n",
    "#####################",
    "# BEGINNING OF SCRIPT",
    "#####################\n",
    "puts 'Migrating users...'\n",
    "def create_or_update_user(user_hash)",
    "  user = User.find_by(user_name: user_hash[:user_name])",
    "  if user.present?",
    "    puts \"Updating user \#{user.user_name}\"",
    "    user.update_attributes(user_hash)",
    "  else",
    "    puts \"Creating user \#{user_hash[:user_name]}\"",
    "    user = User.new(user_hash)",
    "    user.save!",
    "  end\n",
    "  user",
    "end\n\n"
  ].join("\n")

  file.write(header)
end

def write_user_hash(file, user)
  random_password = "#{SecureRandom.base64(40)}1a"
  user_hash = [
    "{",
    "   user_name: \"#{user.user_name}\",",
    "   password: \"#{random_password}\",",
    "   password_confirmation: \"#{random_password}\",",
    "   full_name: \"#{user.full_name}\",",
    "   email: \"#{user.email}\",",
    "   disabled: \"#{user.disabled}\",",
    "   agency_id: @agencies[\"#{user.organization}\"]&.id,",
    "   role_id: @roles[\"#{user.roles.first.id}\"]&.id,",
    "   time_zone: \"#{user.time_zone || "UTC"}\",",
    "   send_mail: #{user.send_mail},",
    "   services: #{user.services},",
    user.code.present? ? "   code: \"#{user.code}\"," : nil,
    user.phone.present? ? "   phone: \"#{user.phone}\"," : nil,
    user.agency_office.present? ? "   agency_office: \"#{user.agency_office}\"," : nil,
    user.position.present? ? "   position: \"#{user.position}\"," : nil,
    user.location.present? ? "   location: \"#{user.location}\"," : nil,
    user.user_group_ids.present? ? "   user_groups: #{user.user_group_ids}.map { |unique_id| @user_groups[unique_id] }.compact," : nil,
    user.locale.present? ? "   locale: \"#{user.locale}\"" : nil,
    "},",
  ].compact.join("\n")

  file.write(user_hash)
end

def write_initializers(file)
  initializers = [
    "timestamp = DateTime.now.strftime('%Y%m%d.%I%M')",
    "log_filename = \"create-users-logs-\#{timestamp}.txt\"",
    "@log = Logger.new(log_filename)",
    "@log.formatter = proc do |severity, datetime, progname, msg|",
    "  \"\#{severity}: \#{msg}\\n\"",
    "end\n",
    "@send_reset_email = ENV['PRIMERO_USER_SEND_RESET_EMAIL'] == 'true'",
    "@admin_user_name = ENV['PRIMERO_ONBOARDING_ADMIN_USER']\n",
    "@agencies = Agency.all.reduce({}){ |acc, elem| acc.merge({ elem.unique_id => elem }) }",
    "@user_groups = UserGroup.all.reduce({}){ |acc, elem| acc.merge({ elem.unique_id => elem }) }",
    "@roles = Role.all.reduce({}){ |acc, elem| acc.merge({ elem.unique_id => elem }) }\n",
    "users = ["
  ].join("\n")

  file.write(initializers)
end

def write_end(file)
  ending = [
    "]\n",
    "stored_users = users.map do |user_hash|",
    "  begin",
    "    user = create_or_update_user(user_hash)",
    "  rescue StandardError => e",
    "    @log.error(\"Trying to save user: \#{user_hash[:user_name]}\")",
    "    @log.error(e)",
    "  end\n",
    "  user\n",
    "end\n",
    "if @send_reset_email",
    "  @admin_user = User.find_by(user_name: @admin_user_name) if @admin_user_name.present?",
    "  stored_users.compact.each do |user|",
    "    user.send_reset_password_instructions",
    "    if @admin_user.present?",
    "      user.send_welcome_email(@admin_user) ",
    "    else",
    "      @log.warn('Skipping welcome email because the admin user was not found.') ",
    "    end",
    "  end",
    "else",
    "  @log.warn('Skipping send_reset_password_instructions because reset email is not enabled.') ",
    "end"
  ].join("\n")

  file.write(ending)
end

def export_users
  config_dir = "#{@export_dir}/users/"
  FileUtils.mkdir_p(config_dir)
  File.open(File.expand_path("#{config_dir}/users.rb"), 'a+') do |file|
    write_header(file)
    write_initializers(file)
    User.each_slice(500) do |batch|
      batch.each do |user|
        begin
          write_user_hash(file, user)
          @log.info("User: #{user.user_name} written successfully")
        rescue StandardError => e
          @log.error(e)
          @log.error("Error when user: #{user.user_name} was written")
        end
      end
    end
    write_end(file)
  end
end

#####################
# BEGINNING OF SCRIPT
#####################
@export_dir = 'seed-files'
FileUtils.mkdir_p(@export_dir)

timestamp = DateTime.now.strftime('%Y%m%d.%I%M')
log_filename = "export-users-logs-#{timestamp}.txt"
@log = Logger.new(log_filename)
@log.formatter = proc do |severity, datetime, progname, msg|
  "#{severity}: #{msg}\n"
end

export_users
