#!/bin/sh
#
# @author Sander de Wit
# @date
# @version
#

# Variables
SCRIPT_VERSION="0.1"
USER="monitor"
HOME_DIRECTORY="/home/$USER/"
TEMP_DIRECTORY=$HOME_DIRECTORY"temp/"
SYSCTL_CONF_FILE="/etc/sysctl.conf"
DOWNLOAD_URL="https://github.com/dtctd/debian/raw/master/"
LOG_FILE=$HOME_DIRECTORY"Hardening.log"

DIALOG_WIDTH=70
SCRIPT_TITLE="Debian hardening script v$SCRIPT_VERSION for Debian 8.2 by Sander de Wit"

function showInfo() {
    CUR_DATE=$(date +%Y-%m-%d"  "%H:%M)
    echo "$CUR_DATE - INFO :: $@" >> $LOG_FILE
    #dialog --title "Installing & Configuring..." --backtitle "$SCRIPT_TITLE" --infobox "\n$@" 5 $DIALOG_WIDTH
}

function showError() {
    CUR_DATE=$(date +%Y-%m-%d"  "%H:%M)
    echo "$CUR_DATE - ERROR :: $@" >> $LOG_FILE
    #dialog --title "Error" --backtitle "$SCRIPT_TITLE" --msgbox "$@" 8 $DIALOG_WIDTH
}

function download() {
    URL="$@"
    wget -q "$URL" >/dev/null 2>&1
}

fuction move() {
    SOURCE="$1"
    DESTINATION="$2"
    IS_ROOT="$3"

    if [ -e "$SOURCE" ]; then
        if [ "$IS_ROOT" == "0" ]; then
            mv "$SOURCE" "$DESTINATION" > /dev/null 2>&1
        else
            sudo mv "$SOURCE" "$DESTINATION" > /dev/null 2>&1
        fi

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

function createFile() {
    FILE="$1"
    IS_ROOT="$2"
    REMOVE_IF_EXISTS="$3"

    if [ -e "$FILE" ] && [ "$REMOVE_IF_EXISTS" == "1" ]; then
        sudo rm "$FILE" > /dev/null
    else
        if [ "$IS_ROOT" == "0" ]; then
            touch "$FILE" > /dev/null
        else
            sudo touch "$FILE" > /dev/null
        fi
    fi
}

function createDirectory() {
    DIRECTORY="$1"
    GOTO_DIRECTORY="$2"
    IS_ROOT="$3"

    if [ ! -d "$DIRECTORY" ]; then
        if [ "$IS_ROOT" == "0" ]; then
            mkdir -p "$DIRECTORY" > /dev/null 2>&1
        else
            sudo mkdir -p "$DIRECTORY" > /dev/null 2>&1
        fi
    fi

    if [ "$GOTO_DIRECTORY" == "1" ]; then
        cd $DIRECTORY
    fi
}

function handleFileBackup() {
    FILE="$1"
    BACKUP="$1.bak"
    IS_ROOT="$2"
    DELETE_ORIGINAL="$3"

    if [ -e "$BACKUP" ]; then
        if [ "$IS_ROOT" == "1" ]; then
            sudo rm "$FILE" > /dev/null 2>&1
            sudo cp "$BACKUP" "$FILE" > /dev/null 2>&1
        else
            rm "$FILE" > /dev/null 2>&1
            cp "$BACKUP" "$FILE" > /dev/null 2>&1
        fi
    else
        if [ "$IS_ROOT" == "1" ]; then
            sudo cp "$FILE" "$BACKUP" > /dev/null 2>&1
        else
            cp "$FILE" "$BACKUP" > /dev/null 2>&1
        fi
    fi

    if [ "$DELETE_ORIGINAL" == "1" ]; then
        sudo rm "$FILE" > /dev/null 2>&1
    fi
}

function installSysctlConfig() {
    showInfo "Optimizing and hardening Debian..."
    handleFileBackup "$SYSCTL_CONF_FILE" 1 1
    createDirectory "$TEMP_DIRECTORY" 1 0
        download $DOWNLOAD_URL"sysctl.conf"

        if [ -e $TEMP_DIRECTORY"sysctl.conf" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"sysctl.conf" $SYSCTL_CONF_FILE)

            if [ "$IS_MOVED" == "1" ]; then
               sysctl -p
            else
                showError "sysctl setup failed!"
            fi
        else
            showError "Download of sysctl.conf failed!"
        fi
}

function configureIptables() {
    showInfo "Configuring iptables rules..."
    createDirectory "$TEMP_DIRECTORY" 1 0
        download $DOWNLOAD_URL"iptables.rules"

        if [ -e $TEMP_DIRECTORY"iptables.rules" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"iptables.rules" "/etc/iptables.rules")

            if [ "$IS_MOVED" == "1" ]; then
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
    createDirectory "$TEMP_DIRECTORY" 1 0
        download $DOWNLOAD_URL"iptablesload"

        if [ -e $TEMP_DIRECTORY"iptablesload" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"iptablesload" "/etc/network/if-pre-up.d/iptablesload")

            if [ "$IS_MOVED" == "1" ]; then
                sudo chmod +x /etc/network/if-pre-up.d/iptablesload
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
    createDirectory "$TEMP_DIRECTORY" 1 0
        download $DOWNLOAD_URL"iptablessave"

        if [ -e $TEMP_DIRECTORY"iptablessave" ]; then
            IS_MOVED=$(move $TEMP_DIRECTORY"iptablessave" "/etc/network/if-pre-up.d/iptablessave")

            if [ "$IS_MOVED" == "1" ]; then
                sudo chmod +x /etc/network/if-pre-up.d/iptablessave
                showInfo "Iptablessave setup succeeded"
            else
                showError "Iptablessave setup failed!"
            fi
        else
            showError "Download of Iptablessave failed!"
        fi
}

# Configure iptable rules
#iptables -F INPUT
#iptables -F OUTPUT
#iptables -F FORWARD
#iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#iptables -A INPUT -s 127.0.0.1/32 -p tcp -m tcp --dport 22 -m state --state NEW -j ACCEPT
#iptables -A INPUT -j DROP
#iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
#iptables -A FORWARD -j DROP
#iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -m state --state NEW -j ACCEPT

installSysctlConfig
configureIptables
configureIptablesLoad
configureIptablesSave