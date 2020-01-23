sudo apt-get update

sudo apt-get install python -y

sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible ansible-test python3 python3-pip -y


virtualenv ansible-venv
source ansible-venv/bin/activate
pip install ansible pywinrm
