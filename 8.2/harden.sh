#!/bin/sh
#
# @author Sander de Wit
# @date
# @version
#

# Variables
SCRIPT_VERSION="0.3"
USER="monitor"
HOME_DIRECTORY="/home/$USER/"
TEMP_DIRECTORY=$HOME_DIRECTORY"temp/"
CRONTAB_FILE="/etc/crontab"
DIST_UPGRADE_FILE="/etc/cron.d/dist_upgrade.sh"
DIST_UPGRADE_LOG_FILE="/var/log/updates.log"
SYSCTL_CONF_FILE="/etc/sysctl.conf"
IPTABLES_RULES_FILE="/etc/iptables.rules"
IPTABLES_LOAD_FILE="/etc/network/if-pre-up.d/iptablesload"
IPTABLES_SAVE_FILE="/etc/network/if-pre-up.d/iptablessave"
DOWNLOAD_URL="https://github.com/dtctd/debian/raw/master/8.2/download/"
LOG_FILE=$HOME_DIRECTORY"Hardening.log"

function showInfo() {
    CUR_DATE=$(date +%Y-%m-%d"  "%H:%M)
    echo "$CUR_DATE - INFO :: $@" >> $LOG_FILE
}

function showError() {
    CUR_DATE=$(date +%Y-%m-%d"  "%H:%M)
    echo "$CUR_DATE - ERROR :: $@" >> $LOG_FILE
}

function download() {
    URL="$@"
    wget -q "$URL" >/dev/null 2>&1
}

function move() {
    SOURCE="$1"
    DESTINATION="$2"

    if [ -e "$SOURCE" ]; then
        mv "$SOURCE" "$DESTINATION" > /dev/null 2>&1

        if [ "$?" == "0" ]; then
            echo 1
        else
            showError "$SOURCE could not be moved to $DESTINATION (error code: $?)"
            echo 0
        fi
    else
        showError "$SOURCE could not be moved to $DESTINATION because the file does not exist"
        echo 0
    fi
}

function createDirectory() {
    DIRECTORY="$1"
    GOTO_DIRECTORY="$2"

    if [ ! -d "$DIRECTORY" ]; then
        mkdir -p "$DIRECTORY" > /dev/null 2>&1
    fi

    if [ "$GOTO_DIRECTORY" == "1" ]; then
        cd $DIRECTORY
    fi
}

function handleFileBackup() {
    FILE="$1"
    BACKUP="$1.bak"
    DELETE_ORIGINAL="$2"

    if [ -e "$BACKUP" ]; then
        rm "$FILE" > /dev/null 2>&1
        cp "$BACKUP" "$FILE" > /dev/null 2>&1
    else
        cp "$FILE" "$BACKUP" > /dev/null 2>&1
    fi

    if [ "$DELETE_ORIGINAL" == "1" ]; then
        rm "$FILE" > /dev/null 2>&1
    fi
}

function appendToFile() {
    FILE="$1"
    CONTENT="$2"

    echo "$CONTENT" | tee -a "$FILE" > /dev/null 2>&1
}

function installSysctlConfig() {
    showInfo "Optimizing and hardening Debian..."
    handleFileBackup "$SYSCTL_CONF_FILE" 1 1
    createDirectory "$TEMP_DIRECTORY" 1
        download $DOWNLOAD_URL"sysctl.conf"

        if [ -e $TEMP_DIRECTORY"sysctl.conf" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"sysctl.conf" $SYSCTL_CONF_FILE)

            if [ "$IS_MOVED" == "1" ]; then
               sysctl -p > /dev/null 2>&1
            else
                showError "sysctl setup failed!"
            fi
        else
            showError "Download of sysctl.conf failed!"
        fi
}

function configureIptables() {
    showInfo "Configuring iptables rules..."
    createDirectory "$TEMP_DIRECTORY" 1
        download $DOWNLOAD_URL"iptables.rules"

        if [ -e $TEMP_DIRECTORY"iptables.rules" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"iptables.rules" $IPTABLES_RULES_FILE)

            if [ "$IS_MOVED" == "1" ]; then
                iptables-restore < /etc/iptables.rules
                showInfo "Iptables setup succeeded"
            else
                showError "Iptables setup failed!"
            fi
        else
            showError "Download of iptables.rules failed!"
        fi
}

function configureIptablesLoad() {
    showInfo "Configuring pre-up load script for iptables..."
    createDirectory "$TEMP_DIRECTORY" 1
        download $DOWNLOAD_URL"iptablesload"

        if [ -e $TEMP_DIRECTORY"iptablesload" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"iptablesload" $IPTABLES_LOAD_FILE)

            if [ "$IS_MOVED" == "1" ]; then
                chmod +x $IPTABLES_LOAD_FILE
                showInfo "Iptablesload setup succeeded"
            else
                showError "Iptablesload setup failed!"
            fi
        else
            showError "Download of iptablesload failed!"
        fi
}

function configureIptablesSave() {
    showInfo "Configuring pre-up script for iptables..."
    createDirectory "$TEMP_DIRECTORY" 1
        download $DOWNLOAD_URL"iptablessave"

        if [ -e $TEMP_DIRECTORY"iptablessave" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"iptablessave" $IPTABLES_SAVE_FILE)

            if [ "$IS_MOVED" == "1" ]; then
                chmod +x $IPTABLES_SAVE_FILE
                showInfo "Iptablessave setup succeeded"
            else
                showError "Iptablessave setup failed!"
            fi
        else
            showError "Download of Iptablessave failed!"
        fi
}

function aptInstall() {
    PACKAGE=$@
    IS_INSTALLED=$(isPackageInstalled $PACKAGE)

    if [ "$IS_INSTALLED" == "1" ]; then
        showInfo "Skipping installation of $PACKAGE. Already installed."
        echo 1
    else
        apt-get -f install > /dev/null 2>&1
        apt-get -y install $PACKAGE > /dev/null 2>&1

        if [ "$?" == "0" ]; then
            showInfo "$PACKAGE successfully installed"
            echo 1
        else
            showError "$PACKAGE could not be installed (error code: $?)"
            echo 0
        fi
    fi
}

function installAutomaticDistUpgrade() {
    showInfo "Enabling automatic system upgrade..."
	createDirectory "$TEMP_DIRECTORY" 1
	download $DOWNLOAD_URL"dist_upgrade.sh"
	IS_MOVED=$(move $TEMP_DIRECTORY"dist_upgrade.sh" "$DIST_UPGRADE_FILE")

	if [ "$IS_MOVED" == "1" ]; then
	    IS_INSTALLED=$(aptInstall cron)
	    chmod +x "$DIST_UPGRADE_FILE" > /dev/null 2>&1
	    handleFileBackup "$CRONTAB_FILE" 1
	    appendToFile "$CRONTAB_FILE" "0 */4  * * * root  $DIST_UPGRADE_FILE >> $DIST_UPGRADE_LOG_FILE"
	else
	    showError "Automatic system upgrade interval could not be enabled"
	fi
}

function cleanUp() {
    showInfo "Cleaning up..."
    apt-get -y autoremove > /dev/null 2>&1
    sleep 1
    apt-get -y autoclean > /dev/null 2>&1
    sleep 1
    apt-get -y clean > /dev/null 2>&1
    sleep 1

    if [ -e "$TEMP_DIRECTORY" ]; then
        rm -R "$TEMP_DIRECTORY" > /dev/null 2>&1
    fi
}

# Check if the script runs as root
if [ $EUID -ne 0 ]; then
    clear
    echo "This script must be run as root" 1>&2
    echo ""
    exit 1
else
    installSysctlConfig
    configureIptables
    configureIptablesLoad
    configureIptablesSave
    cleanUp
fi