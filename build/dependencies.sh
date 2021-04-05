#!/bin/sh

sudo add-apt-repository universe
sudo apt update
sudo apt-get update

sudo apt-get install python3 python3-pip python3-venv python3-dev -y
sudo apt install python2
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
sudo python2 get-pip.py



python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

pip3 --version
pip3 install --upgrade wheel
pip3 install ansible pywinrm

pip2 --version
pip2 install --upgrade wheel
