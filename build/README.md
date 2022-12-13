# Build and Testing Instructions

## Invoke-CollectionTests.ps1

Use this file when you just want to do a one-time run through the module's tests.
By default, it will stand up the environment via Vagrant and VirtualBox, and run all module tests just like CI.

You can optionally provide `-TestTarget` to specify a single module's integration tests to run in isolation.

When complete, the VMs will be destroyed.

## Start-VagrantEnvironment.ps1

Use this file to stand up the Vagrant environment and install necessary prerequisites without running any tests.
Files placed in a `build/vagrant-files/` directory will be synced to the host under the `~/files/` directory.

To interact with Ansible on the VM, do the following:

1. Copy any playbooks you'd like to run into the `build/vagrant-files` directory
1. SSH into the ansible server VM: `vagrant ssh choco_ansible_server`
1. Dot-source the ansible venv: `. ~/ansible-venv/bin/activate`

From here you can proceed either in Bash or open `pwsh` and follow the appropriate section below.

### Pwsh

```ps1
$inventory = '~/.ansible/collections/ansible_collections/chocolatey/chocolatey/tests/integration/inventory.winrm'

# Either run the playbook you want from the ~/files/ directory
ansible-playbook -i $inventory ./files/playbook-name.yml

# Or run the normal collection tests directly
cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey/

ansible-test windows-integration -vvv --requirements --continue-on-error
ansible-test sanity -vvvvv --requirements
ansible-test coverage xml -vvvvv --requirements
```

### Bash

```sh
export INVENTORY=~/.ansible/collections/ansible_collections/chocolatey/chocolatey/tests/integration/inventory.winrm

# Either run the playbook you want from the ~/files/ directory
ansible-playbook -i $INVENTORY ./files/playbook-name.yml

# Or run the normal collection tests directly
cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey/

ansible-test windows-integration -vvv --requirements --continue-on-error
ansible-test sanity -vvvvv --requirements
ansible-test coverage xml -vvvvv --requirements
```

### Cleaning Up

Once done, the Vagrant environment can be destroyed at any time by `exit`-ing the SSH session and running `vagrant destroy` from the `build` directory.
