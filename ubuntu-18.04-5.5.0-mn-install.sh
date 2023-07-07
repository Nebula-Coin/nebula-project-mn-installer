#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="nebulaproject.conf"
NEBULAPROJECT_DAEMON="/usr/local/bin/nebulaprojectd"
NEBULAPROJECT_CLI="/usr/local/bin/nebulaproject-cli"
NEBULAPROJECT_REPO="https://github.com/Nebula-Coin/nebula-project-coin.git"
NEBULAPROJECT_PARAMS="https://github.com/Nebula-Coin/nebula-project-coin/releases/download/v5.5.0/util.zip"
NEBULAPROJECT_LATEST_RELEASE="https://github.com/Nebula-Coin/nebula-project-coin/releases/download/v5.5.0/nebulaproject-5.5.0-ubuntu18-daemon.zip"
COIN_BOOTSTRAP='https://bootstrap.nebulaproject.io/boot_strap.tar.gz'
COIN_ZIP=$(echo $NEBULAPROJECT_LATEST_RELEASE | awk -F'/' '{print $NF}')
COIN_CHAIN=$(echo $COIN_BOOTSTRAP | awk -F'/' '{print $NF}')
COIN_NAME='NebulaProject'
CONFIGFOLDER='.nebulaproject'
COIN_BOOTSTRAP_NAME='boot_strap.tar.gz'

DEFAULT_NEBULAPROJECT_PORT=1818
DEFAULT_NEBULAPROJECT_RPC_PORT=1819
DEFAULT_NEBULAPROJECT_USER="nebulaproject"
NEBULAPROJECT_USER="nebulaproject"
NODE_IP=NotCheckedYet
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function download_bootstrap() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME BootStrap${NC}"
  mkdir -p /opt/chaintmp/
  cd /opt/chaintmp >/dev/null 2>&1
  rm -rf boot_strap* >/dev/null 2>&1
  wget $COIN_BOOTSTRAP >/dev/null 2>&1
  cd /home/$NEBULAPROJECT_USER/$CONFIGFOLDER
  rm -rf sporks zerocoin blocks database chainstate peers.dat
  cd /opt/chaintmp >/dev/null 2>&1
  tar -zxf $COIN_BOOTSTRAP_NAME
  cp -Rv cache/* /home/$NEBULAPROJECT_USER/$CONFIGFOLDER/ >/dev/null 2>&1
  chown -Rv $NEBULAPROJECT_USER /home/$NEBULAPROJECT_USER/$CONFIGFOLDER >/dev/null 2>&1
  cd ~ >/dev/null 2>&1
  rm -rf /opt/chaintmp >/dev/null 2>&1
}

function install_params() {
  echo -e "${GREEN}Downloading and Installing $COIN_NAME Params Files${NC}"
  mkdir -p /opt/tmp/
  cd /opt/tmp
  rm -rf util* >/dev/null 2>&1
  wget $NEBULAPROJECT_PARAMS >/dev/null 2>&1
  unzip util.zip >/dev/null 2>&1
  chmod -Rv 777 /opt/tmp/util/fetch-params.sh >/dev/null 2>&1
  runuser -l $NEBULAPROJECT_USER -c '/opt/tmp/util/./fetch-params.sh' >/dev/null 2>&1
}

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME Daemon{NC}"
    #kill wallet daemon
	systemctl stop $NEBULAPROJECT_USER.service
	
	#Clean block chain for Bootstrap Update
    cd $CONFIGFOLDER >/dev/null 2>&1
    rm -rf *.pid *.lock database sporks chainstate zerocoin blocks >/dev/null 2>&1
	
    #remove binaries and NebulaProject utilities
    cd /usr/local/bin && sudo rm nebulaproject-cli nebulaproject-tx nebulaprojectd > /dev/null 2>&1 && cd
    echo -e "${GREEN}* Done${NC}";
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *18.04* ]]; then
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

function prepare_system() {

echo -e "Prepare the system to install NebulaProject master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding Pivx PPA repository"
apt-add-repository -y ppa:pivx/pivx >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get upgrade >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev ufw fail2ban pwgen curl unzip >/dev/null 2>&1
NODE_IP=$(curl -s4 icanhazip.com)
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt-get -y upgrade"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:pivx/pivx"
    echo "apt-get update"
    echo "apt install -y git make build-essential libtool bsdmainutils autotools-dev autoconf pkg-config automake python3 libssl-dev libgmp-dev libevent-dev libboost-all-dev libdb4.8-dev libdb4.8++-dev unzip"
    exit 1
fi
clear

}

function ask_yes_or_no() {
  read -p "$1 ([Y]es or [N]o | ENTER): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

function compile_nebulaproject() {
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "4" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 4G of RAM without SWAP, creating 8G swap file.${NC}"
    SWAPFILE=/swapfile
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=8388608
    chown root:root $SWAPFILE
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
else
  echo -e "${GREEN}Server running with at least 4G of RAM, no swap needed.${NC}"
fi
clear
  echo -e "Clone git repo and compile it. This may take some time."
  cd $TMP_FOLDER
  git clone $NEBULAPROJECT_REPO nebulaproject
  cd nebulaproject
  ./autogen.sh
  ./configure
  make
  strip src/nebulaprojectd src/nebulaproject-cli src/nebulaproject-tx
  make install
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function copy_nebulaproject_binaries(){
   cd /root
  wget $NEBULAPROJECT_LATEST_RELEASE
  unzip nebulaproject-5.5.0-ubuntu18-daemon.zip
  cp nebulaproject-cli nebulaprojectd nebulaproject-tx /usr/local/bin >/dev/null
  chmod 755 /usr/local/bin/nebulaproject* >/dev/null
  clear
}

function install_nebulaproject(){
  echo -e "Installing NebulaProject files."
  echo -e "${GREEN}You have the choice between source code compilation (slower and requries 4G of RAM or VPS that allows swap to be added), or to use precompiled binaries instead (faster).${NC}"
  if [[ "no" == $(ask_yes_or_no "Do you want to perform source code compilation?") || \
        "no" == $(ask_yes_or_no "Are you **really** sure you want compile the source code, it will take a while?") ]]
  then
    copy_nebulaproject_binaries
    clear
  else
    compile_nebulaproject
    clear
  fi
}

function enable_firewall() {
  echo -e "Installing fail2ban and setting up firewall to allow ingress on port ${GREEN}$NEBULAPROJECT_PORT${NC}"
  ufw allow $NEBULAPROJECT_PORT/tcp comment "NebulaProject MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl start fail2ban >/dev/null 2>&1
}

function systemd_nebulaproject() {
  cat << EOF > /etc/systemd/system/$NEBULAPROJECT_USER.service
[Unit]
Description=NebulaProject service
After=network.target
[Service]
ExecStart=$NEBULAPROJECT_DAEMON -conf=$NEBULAPROJECT_FOLDER/$CONFIG_FILE -datadir=$NEBULAPROJECT_FOLDER
ExecStop=$NEBULAPROJECT_CLI -conf=$NEBULAPROJECT_FOLDER/$CONFIG_FILE -datadir=$NEBULAPROJECT_FOLDER stop
Restart=always
User=$NEBULAPROJECT_USER
Group=$NEBULAPROJECT_USER

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $NEBULAPROJECT_USER.service
  systemctl enable $NEBULAPROJECT_USER.service
}

function ask_port() {
read -p "NEBULAPROJECT Port: " -i $DEFAULT_NEBULAPROJECT_PORT -e NEBULAPROJECT_PORT
: ${NEBULAPROJECT_PORT:=$DEFAULT_NEBULAPROJECT_PORT}
}

function ask_user() {
  echo -e "${GREEN}The script will now setup NebulaProject user and configuration directory. Press ENTER to accept defaults values.${NC}"
  read -p "NebulaProject user: " -i $DEFAULT_NEBULAPROJECT_USER -e NEBULAPROJECT_USER
  : ${NEBULAPROJECT_USER:=$DEFAULT_NEBULAPROJECT_USER}

  if [ -z "$(getent passwd $NEBULAPROJECT_USER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $NEBULAPROJECT_USER
    echo "$NEBULAPROJECT_USER:$USERPASS" | chpasswd

    NEBULAPROJECT_HOME=$(sudo -H -u $NEBULAPROJECT_USER bash -c 'echo $HOME')
    DEFAULT_NEBULAPROJECT_FOLDER="$NEBULAPROJECT_HOME/.nebulaproject"
    read -p "Configuration folder: " -i $DEFAULT_NEBULAPROJECT_FOLDER -e NEBULAPROJECT_FOLDER
    : ${NEBULAPROJECT_FOLDER:=$DEFAULT_NEBULAPROJECT_FOLDER}
    mkdir -p $NEBULAPROJECT_FOLDER
    chown -R $NEBULAPROJECT_USER: $NEBULAPROJECT_FOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $NEBULAPROJECT_PORT ]] || [[ ${PORTS[@]} =~ $[NEBULAPROJECT_PORT+1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $NEBULAPROJECT_FOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$DEFAULT_NEBULAPROJECT_RPC_PORT
listen=1
server=1
daemon=1
port=$NEBULAPROJECT_PORT
#External NebulaProject IPV4
addnode=135.181.254.116:1818
addnode=135.181.193.63:1818
addnode=65.21.242.191:1818
addnode=65.109.182.123:1818
addnode=199.127.140.224:1818
addnode=199.127.140.225:1818
addnode=[2a01:04f9:c012:4fb0::0001]:1818
addnode=[2a01:04f9:c011:24ca::0001]:1818

#External WhiteListing IPV4
whitelist=135.181.254.116
whitelist=135.181.193.63
whitelist=65.21.242.191
whitelist=65.109.182.123
whitelist=23.245.6.173
whitelist=199.127.140.224
whitelist=199.127.140.225

#External WhiteListing IPV6
whitelist=[2a01:04f9:c012:4fb0::0001]
whitelist=[2a01:04f9:c011:24ca::0001]
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e NEBULAPROJECT_KEY
  if [[ -z "$NEBULAPROJECT_KEY" ]]; then
  su $NEBULAPROJECT_USER -c "$NEBULAPROJECT_DAEMON -conf=$NEBULAPROJECT_FOLDER/$CONFIG_FILE -datadir=$NEBULAPROJECT_FOLDER -daemon"
  sleep 15
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$NEBULAPROJECT_USER | grep $NEBULAPROJECT_DAEMON)" ]; then
   echo -e "${RED}NebulaProjectd server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  NEBULAPROJECT_KEY=$(su $NEBULAPROJECT_USER -c "$NEBULAPROJECT_CLI -conf=$NEBULAPROJECT_FOLDER/$CONFIG_FILE -datadir=$NEBULAPROJECT_FOLDER createmasternodekey")
  su $NEBULAPROJECT_USER -c "$NEBULAPROJECT_CLI -conf=$NEBULAPROJECT_FOLDER/$CONFIG_FILE -datadir=$NEBULAPROJECT_FOLDER stop"
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $NEBULAPROJECT_FOLDER/$CONFIG_FILE
  cat << EOF >> $NEBULAPROJECT_FOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
masternodeaddr=$NODE_IP:$NEBULAPROJECT_PORT
masternodeprivkey=$NEBULAPROJECT_KEY
EOF
  chown -R $NEBULAPROJECT_USER: $NEBULAPROJECT_FOLDER >/dev/null
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "NebulaProject Masternode is up and running as user ${GREEN}$NEBULAPROJECT_USER${NC} and it is listening on port ${GREEN}$NEBULAPROJECT_PORT${NC}."
 echo -e "${GREEN}$NEBULAPROJECT_USER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$NEBULAPROJECT_FOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $NEBULAPROJECT_USER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $NEBULAPROJECT_USER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODE_IP:$NEBULAPROJECT_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$NEBULAPROJECT_KEY${NC}"
 echo -e "Please check NebulaProject is running with the following command: ${GREEN}systemctl status $NEBULAPROJECT_USER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  ask_user
  install_params
  download_bootstrap
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  systemd_nebulaproject
  important_information
}


##### Main #####
clear
purgeOldInstallation
checks
prepare_system
install_nebulaproject
setup_node
