export DEBIAN_FRONTEND=noninteractive

sudo apt-get install python -y

sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible -y
