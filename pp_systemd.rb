require 'erb'
require 'yaml'

unless File.exist? "pp_watchdog.rb"
    puts "ERROR: Watchdog Script not found.\nPlease change to the PalPal directory before running this script."
    exit 1
end

unless File.exist? "config.yml"
    puts "ERROR: Configuration not found.\nPlease change to the PalPal directory before running this script."
    exit 1
end

# Load config
config = YAML.load_file('config.yml')

# Write palserver Unit
description = "Palworld Dedicated Server"
unit_user = "steam"
work_dir = config["PalPalSettings"]["PalServerPath"]
exec_start = "#{config["PalPalSettings"]["PalServerPath"]}/PalServer.sh"

template = File.read("templates/service.erb")
File.open("/etc/systemd/system/palserver.service", 'w') do |f|
    f.write ERB.new(template).result(binding)
    puts "Wrote /etc/systemd/system/palserver.service"
end

# Write palpal Unit
description = "PalPal Watchdog"
unit_user = "root"
work_dir = Dir.pwd
exec_start = "#{File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])} #{Dir.pwd}/pp_watchdog.rb"

template = File.read("templates/service.erb")
File.open("/etc/systemd/system/palpal.service", 'w') do |f|
    f.write ERB.new(template).result(binding)
    puts "Wrote /etc/systemd/system/palpal.service"
end

puts ("Units were written successfully.\n\nIn order for the changes to take effect, please reload systemd by running:\n\n  init q\n\nAfterwards, start the new services by running:\n\n  systemctl start palserver\n  systemctl start palpal\n\n")