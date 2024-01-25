require 'erb'
require 'yaml'

config = YAML.load_file('config.yml')

# Prepare INI String
option_settings = ""
config["PalWorldSettings"].each do |k, v|
    option_settings += "#{k}=#{v},"
end
option_settings = option_settings.chomp(',')

# Write config
template = File.read("templates/PalWorldSettings.ini.erb")
File.open("#{config["PalPalSettings"]["PalServerPath"]}/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini", 'w') do |f|
    f.write ERB.new(template).result(binding)
    puts "Wrote configuration to #{f.inspect}\n\nIf you made any changes, be sure to restart palserver like this:\n\n  systemctl restart palserver\n\n"
end