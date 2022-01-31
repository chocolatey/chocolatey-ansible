#!/bin/sh

sudo add-apt-repository universe
sudo apt-get update
sudo apt-get install software-properties-common
sudo apt-get install python3 python3-pip python3-venv python3-dev -y

python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

pip3 install --upgrade wheel
pip3 install 'pyOpenSSL<22.0.0'
pip3 install pywinrm
pip3 install "$ANSIBLE_PACKAGE"

pip3 --version
ansible --version
