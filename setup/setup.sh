#! /usr/bin/env bash

## idempotent setup script for Linux systems

# TODO: detect and create swap file on demand

USER=$(whoami)
UNPRIVILEGED_USER=$(logname)
if [[ $USER != "root" ]]; then
    echo "this script has to be executed with \"root\" privileges"
    echo "run as: sudo ./setup.sh"
    exit 1
fi

# install software
echo -e "\n\n## install software if necessary\n"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
fi

if [[ $ID == "debian" || $NAME == "ubuntu" ]]; then
    echo "\"$PRETTY_NAME\" detected"
    apt install -y julia redis sed nano htop
elif [[ $ID == "fedora" ]]; then
    echo "\"$PRETTY_NAME\" detected"
    dnf install julia redis sed nano htop
else
    echo "unsupported operating system: \"$PRETTY_NAME\" detected"
    exit 1
fi

# redirect from port 80 => 8000
# check if redirect rule already exists
iptables -t nat -C PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000 2> /dev/null
if [[ $? != 0 ]]; then
    echo -e "\n\n## setup port redirect\n"
    iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000
fi

# install julia packages
echo -e "\n\n## install and update Julia dependencies\n"
cd "$(dirname "$0")"
sudo -u "$UNPRIVILEGED_USER" ./dependencies.jl

# setup systemd service unit
echo -e "\n\n## configure systemd service unit\n"
cd ..
APP_PATH=$(pwd)/App.jl
APP_DIR=$(pwd)
UNIT_DIR="/etc/systemd/system"

sed "s|APP|$APP_PATH|" ./setup/stockoverview.service > ./setup/stockoverview.service_tmp
sed -i "s|DIR|$APP_DIR|" ./setup/stockoverview.service_tmp
sed -i "s|USER|$UNPRIVILEGED_USER|" ./setup/stockoverview.service_tmp
mv ./setup/stockoverview.service_tmp "${UNIT_DIR}/stockoverview.service"
chmod +r "${UNIT_DIR}/stockoverview.service"

systemctl daemon-reload

exit 0