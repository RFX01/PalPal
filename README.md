# PalPal - PalServer Helper Tool
This is a tool to help manage a Palworld Dedicated Server.

## Features
- Configure Server using YAML File instead of single line INI
- Automated Systemd Unit Setup
- Player Join/Leave broadcast messages
- Automatic World Backup
- Player Whitelist

**WARNING:** If the PalPal Watchdog stops running for any reason, the whitelist is no longer enforced. Additionally, if a non-whitelisted player joins while the Watchdog isn't running, they will not be kicked retroactively.

If a player is kicked as a result of not being whitelisted, the game client will softlock on the loading screen due to a bug.

## Setup
This guide assumes you already have a PalServer installed via SteamCMD. If you haven't done that yet, please do so.

**Install Dependencies (Ubuntu/Debian)**
```
sudo apt update
sudo apt install ruby ruby-dev rubygems git make gcc
```

**Install Dependencies (RHEL/Rocky)**
```
sudo dnf install epel-release
sudo dnf install ruby ruby-devel rubygems git make gcc
```

**Download PalPal**

Before running this command, please change into the directory you want to store PalPal.

```
git clone https://github.com/RFX01/PalPal.git
```

**Change into PalPal directory**
```
cd PalPal
```

**Install Ruby Gems**
```
sudo bundle install
```

**Create config file**
```
cp config.example.yml config.yml
```

**Configure PalPal & PalServer**

Edit the configuration file to your liking:
```
nano config.yml
```

Once you're done making changes, run the following command to apply changes to PalWorldSettings:
```
ruby pp_config.rb
```

You will need to run this command every time you make changes to the PalServerSettings section in config.yml. Make sure you restart palserver if it's already running to apply the changes.

**Install systemd Units**
```
sudo ruby pp_systemd.rb
```

**INFO:** By default, PalPal Watchdog will run as root for ease of setup. Ideally you wouldn't do this. To change this, you will need a user that has permission to write into the backup directory and read from the server directory. To change the user, open pp_systemd.rb and change the line that says `unit_user = "root"` to a different username.

**Reload systemd**
```
init q
```

**Configure PalServer using PalPal Config Tool**
```
ruby pp_config.rb
```

**Start PalServer**
```
sudo systemctl start palserver
```

If you get a segmentation fault after joining, make sure the steam user has write permission in the server directory.

**Start PalPal**
```
sudo systemctl start palpal
```

**(Optional) Enable PalServer & PalPal to start at boot**
```
sudo systemctl enable palserver
sudo systemctl enable palpal
```