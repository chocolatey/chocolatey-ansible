#!/bin/sh

sudo add-apt-repository universe
sudo apt-get update
sudo apt-get install software-properties-common
sudo apt-get install python3 python3-pip python3-venv python3-dev -y

# Ensure pwsh is installed (Ansible requires this for some sanity tests)
sudo apt-get install -y wget apt-transport-https software-properties-common
# Download the Microsoft repository GPG keys
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
# Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb
# Update the list of packages after we added packages.microsoft.com
sudo apt-get update
# Install PowerShell
sudo apt-get install -y powershell

python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

pip3 install --upgrade wheel
pip3 install 'pyOpenSSL<22.0.0'
pip3 install pywinrm
pip3 install "$ANSIBLE_PACKAGE"

pip3 --version
ansible --version
