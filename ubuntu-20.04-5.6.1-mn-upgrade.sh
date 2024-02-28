#!/bin/bash

CONFIG_FILE="nebulaproject.conf"
NEBULAPROJECT_DAEMON="/usr/local/bin/nebulaprojectd"
NEBULAPROJECT_CLI="/usr/local/bin/nebulaproject-cli"
NEBULAPROJECT_REPO="https://github.com/Nebula-Coin/nebula-project-coin.git"
NEBULAPROJECT_PARAMS="https://github.com/Nebula-Coin/nebula-project-coin/releases/download/v5.6.1/util.zip"
NEBULAPROJECT_LATEST_RELEASE="https://github.com/Nebula-Coin/nebula-project-coin/releases/download/v5.6.1/nebulaproject-5.6.1-ubuntu20-daemon.zip"
COIN_BOOTSTRAP='https://bootstrap.nebulaproject.io/boot_strap.tar.gz'
COIN_ZIP=$(echo $NEBULAPROJECT_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')

DEFAULT_NEBULAPROJECT_PORT=1818
DEFAULT_NEBULAPROJECT_RPC_PORT=1819
DEFAULT_NEBULAPROJECT_USER="nebulaproject"
NEBULAPROJECT_USER="nebulaproject"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME Daemon{NC}"
    #kill wallet daemon
	systemctl stop $NEBULAPROJECT_USER.service
	
	#Clean block chain for Bootstrap Update
    cd $CONFIGFOLDER >/dev/null 2>&1
    rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
	
    #remove binaries and NebulaProject utilities
    cd /usr/local/bin && sudo rm nebulaproject-cli nebulaproject-tx nebulaprojectd > /dev/null 2>&1 && cd
    echo -e "${GREEN}* Done${NONE}";
}


function download_bootstrap() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME BootStrap${NC}"
  mkdir -p /root/tmp
  cd /root/tmp >/dev/null 2>&1
  rm -rf boot_strap* >/dev/null 2>&1
  wget -q $COIN_BOOTSTRAP
  cd $CONFIGFOLDER >/dev/null 2>&1
  rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
  cd /root/tmp >/dev/null 2>&1
  tar -zxf $COIN_CHAIN /root/tmp >/dev/null 2>&1
  cp -Rv cache/* $CONFIGFOLDER >/dev/null 2>&1
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *20.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 18.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $NEBULAPROJECT_DAEMON)" ] || [ -e "$NEBULAPROJECT_DAEMON" ] ; then
  echo -e "${GREEN}\c"
  echo -e "NebulaProject is already installed. Exiting..."
  echo -e "{NC}"
  exit 1
fi
}


function copy_nebulaproject_binaries(){
  cd /root
  apt-get install build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libgmp-dev libevent-dev libboost-all-dev libsodium-dev cargo libminiupnpc-dev libnatpmp-dev libzmq3-dev -y
  wget $NEBULAPROJECT_LATEST_RELEASE
  unzip nebulaproject-5.6.1-ubuntu20-daemon.zip
  cp nebulaproject-cli nebulaprojectd nebulaproject-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/nebulaproject* >/dev/null
  clear
}

function install_nebulaproject(){
  echo -e "Installing NebulaProject files."
  copy_nebulaproject_binaries
  clear
}


function systemd_nebulaproject() {
sleep 2
systemctl start $NEBULAPROJECT_USER.service
}


function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "NebulaProject Masternode Upgraded to the Latest Version{NC}"
 echo -e "Commands to Interact with the service are listed below{NC}"
 echo -e "Start: ${RED}systemctl start $NEBULAPROJECT_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $NEBULAPROJECT_USER.service${NC}"
 echo -e "Please check NebulaProject is running with the following command: ${GREEN}systemctl status $NEBULAPROJECT_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
	download_bootstrap
	systemd_nebulaproject
	important_information
}


##### Main #####
clear
purgeOldInstallation
checks
install_nebulaproject

