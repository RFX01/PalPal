require 'yaml'
require 'logger'
require 'rcon'
require 'csv'
require 'fileutils'

# RCON Call
def rcon_exec(command)
    begin
        $logger.info("Sending command: '#{command}'")
        return $client.execute(command)
    rescue
        $logger.error("Failed to execute RCON Command: '#{command}'")
        $logger.warn("Attempting to reconnect to PalServer RCON.")
        rcon_reconnect
        return nil
    end
end

# Reconnect in case of connect failure
def rcon_reconnect
    begin
        $client.authenticate!(ignore_first_packet: false)
        $logger.info("Successfully connected to PalServer RCON.")
        return true
    rescue
        $logger.error("Failed to connect to PalServer")
        return false
    end
end

# Initialize logging
$logger = Logger.new("watchdog.log")
$logger.level = Logger::INFO

# Load Cofiguration
config = YAML.load_file('config.yml')
$logger.info("Loaded PalPal configuration.")

# Initialize RCON
$logger.info("Initializing RCON connection.")
$client = Rcon::Client.new(host: "127.0.0.1", port: 25575, password: config["PalPalSettings"]["RconPassword"])
while !rcon_reconnect
    sleep config["PalPalSettings"]["WatchdogInterval"]
end

# Watchdog loop
$logger.info("Entering Watchdog Loop.")
player_list = nil
# The \xA0\x80 stuff is a janky hack to work around the fact that you can't usually put spaces in broadcast messages
rcon_exec("Broadcast PalPal\xA0\x80is\xA0\x80now\xA0\x80watching\xA0\x80this\xA0\x80Server.")
loop do
    # Wait a bit so we don't blast the server
    sleep config["PalPalSettings"]["WatchdogInterval"]

    # Get player list
    player_response = rcon_exec("ShowPlayers")
    if player_response.nil?
        $logger.warn("Skipping watchdog run due to RCON connection failure.")
        next
    end

    new_player_list = CSV.parse(player_response.body, headers: true)
    if player_list.nil?
        # Handle first loop run
        player_list = new_player_list
    else
        # Determine difference between player lists (bit janky this section, maybe refactor at some point)
        players_joined = []
        players_left = []

        player_list.each do |player|
            present = true
            new_player_list.each do |nplayer|
                if nplayer["steamid"] == player["steamid"]
                    present = false
                end
            end
            if present
                players_left.push(player)
            end
        end

        new_player_list.each do |nplayer|
            present = true
            player_list.each do |player|
                if nplayer["steamid"] == player["steamid"]
                    present = false
                end
            end
            if present
                players_joined.push(nplayer)
            end
        end

        # Broadcast join messages
        if config["PalPalSettings"]["JoinBroadcast"]
            players_joined.each do |jplayer|
                $logger.info("Detected Player Join: #{jplayer.inspect}")
                rcon_exec("Broadcast #{jplayer["name"].gsub(" ", "\xA0\x80")}\xA0\x80joined\xA0\x80the\xA0\x80world.")
            end
        end

        # Broadcast leave messages
        if config["PalPalSettings"]["LeaveBroadcast"]
            players_left.each do |lplayer|
                $logger.info("Detected Player Leave: #{lplayer.inspect}")
                rcon_exec("Broadcast #{lplayer["name"].gsub(" ", "\xA0\x80")}\xA0\x80left\xA0\x80the\xA0\x80world.")
            end
        end

        # Handle Whitelist
        if config["PalPalSettings"]["Whitelist"]["Enable"]
            compare_list = players_joined
            if config["PalPalSettings"]["Whitelist"]["RetroactiveKick"]
                # Check all players against whitelist instead of only recently joined players
                compare_list = new_player_list
            end

            compare_list.each do |player|
                is_whitelisted = false
                config["PalPalSettings"]["Whitelist"]["SteamIDs"].each do |steamid|
                    if player["steamid"] == steamid
                        is_whitelisted = true
                    end
                end
                # Kick player if they're not whitelisted
                unless is_whitelisted
                    rcon_exec("KickPlayer #{player["steamid"]}")
                    rcon_exec("Broadcast Kicked\xA0\x80non-whitelisted\xA0\x80player\xA0\x80#{player["name"].gsub(" ", "\xA0\x80")}.")
                    $logger.warn("Kicked non-whitelisted player: #{player.inspect}")
                end
            end
        end

        # Update Player List
        player_list = new_player_list
    end

    # Handle Backup
    if config["PalPalSettings"]["AutoBackup"]["Enable"]
        # Create backup dir if it doesn't exist
        unless File.directory?(config["PalPalSettings"]["AutoBackup"]["BackupPath"])
            $logger.warn("Configured backup directory '#{config["PalPalSettings"]["AutoBackup"]["BackupPath"]}' doesn't exist and will now be created.")
            FileUtils.mkdir_p(config["PalPalSettings"]["AutoBackup"]["BackupPath"])
        end

        # Get age of latest backup
        directories = Dir.glob("#{config["PalPalSettings"]["AutoBackup"]["BackupPath"]}/*").select { |f| File.directory? f }
        newest_folder = directories.sort_by { |folder| File.mtime(folder) }.reverse.first
        age_minutes = 0
        if newest_folder
            age_seconds = Time.now - File.mtime(newest_folder)
            age_minutes = age_seconds / 60
        end

        # Create backup if latest backup is older than configured interval
        if age_minutes > config["PalPalSettings"]["AutoBackup"]["IntervalMinutes"]
            $logger.info("Starting world backup.")
            target_dir = "#{config["PalPalSettings"]["AutoBackup"]["BackupPath"]}/#{Time.now.strftime('%Y%m%d_%H%M%S')}"
            if config["PalPalSettings"]["AutoBackup"]["Broadcast"]
                rcon_exec("Broadcast Latest\xA0\x80backup\xA0\x80is\xA0\x80#{age_minutes.round}\xA0\x80minutes\xA0\x80old.")
                rcon_exec("Broadcast Saving\xA0\x80world\xA0\x80to\xA0\x80run\xA0\x80backup.")
            end
            rcon_exec("Save")
            sleep 10
            if config["PalPalSettings"]["AutoBackup"]["Broadcast"]
                rcon_exec("Broadcast Waited\xA0\x8010\xA0\x80seconds\xA0\x80for\xA0\x80save\xA0\x80to\xA0\x80complete.\xA0\x80Copying\xA0\x80data.")
            end
            FileUtils.mkdir_p(target_dir)
            FileUtils.cp_r "#{config["PalPalSettings"]["PalServerPath"]}/Pal/Saved/.", target_dir
            if config["PalPalSettings"]["AutoBackup"]["Broadcast"]
                rcon_exec("Broadcast Backup\xA0\x80completed\xA0\x80successfully.")
            end
            $logger.info("World backup complete.")
        end

        # Remove Old Backups
        cutoff_time = Time.now - (config["PalPalSettings"]["AutoBackup"]["RetentionDays"] * 24 * 60 * 60)
        old_backups = directories.select { |folder| File.mtime(folder) < cutoff_time }
        old_backups.each do |bak_dir|
            $logger.warn("Deleting old Backup #{bak_dir}")
            # Make sure backup dir is properly set and not crazy short
            if bak_dir.include? "#{config["PalPalSettings"]["AutoBackup"]["BackupPath"]}/" && bak_dir.length > 4
                FileUtils.rm_rf(bak_dir)
                if config["PalPalSettings"]["AutoBackup"]["Broadcast"]
                    rcon_exec("Broadcast Removed\xA0\x80old\xA0\x80backup\xA0\x80#{bak_dir}")
                end
            else
                # Failsafe in case something goes wrong and deletion outside backup dir is attempted
                $logger.error("Something went HORRIBLY wrong. Attempt to delete '#{bak_dir}' has been blocked.")
                rcon_exec("Broadcast WARNING:\xA0\x80Backup\xA0\x80Failure")
                rcon_exec("Broadcast Dangerous\xA0\x80deletion\xA0\x80has\xA0\x80been\xA0\x80blocked.")
                rcon_exec("Broadcast See\xA0\x80watchdog.log\xA0\x80for\xA0\x80more\xA0\x80information.")
            end
        end
    end
end
