# Beta-Testing Chocolatey with the Ansible Collection

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
  - [Vagrant](#vagrant)
  - [Generic](#generic)
- [Running `ansible-test`](#running-ansible-test)

## Prerequisites

Either:

- [Vagrant][vagrant-download]
- [VirtualBox][vbox-download]

Or:

- Windows VM
- Linux VM (Ubuntu 18.10)

[vagrant-download]: https://www.vagrantup.com/downloads
[vbox-download]: https://www.virtualbox.org/wiki/Downloads

## Getting Started

A `Vagrantfile` is provided for ease of use, which simplifies the necessary setup.
If you would like to setup your own VMs or servers for the purposes of this testing, see the [Generic](#generic) instructions.

Otherwise, follow the [Vagrant](#vagrant) instructions.

Once your VMs or servers are ready, follow the instructions in [Running `ansible-test`](#running-ansible-test) to run through the collection tests.

### Vagrant

1. Download the nupkg containing the Chocolatey version you'd like to test.
1. Place the nupkg in the `provision-files` folder.
1. Run `vagrant up` to spin up the Ubuntu 'server' and Windows 10 'client' VMs.

The Vagrant provisioner will by default install the most recent Chocolatey nupkg version (including pre-release versions) placed in the `provision-files` folder.
However, all files in this folder will still be copied to the VM under `C:\packages`.
You may wish to take a snapshot of the client VM after provisioning, to allow you to revert back to this point and manually install a different Chocolatey version from the folder for testing purposes.

Continue on to the [Running `ansible-test`](#running-ansible-test) section.

### Generic

1. Before continuing, prepare a Windows VM and a Linux VM (these instructions assume you're using Ubuntu 18.10 or newer, and a Windows 10 client)
1. Run the following commands on the Linux server to setup Ansible and install the Chocolatey collection:

    ```sh
    sudo apt-get update
    sudo apt-get install python3-venv -y

    python3 -m venv ~/ansible
    source ~/ansible/bin/activate

    pip3 install --upgrade wheel
    pip3 install ansible pywinrm

    ansible-galaxy collection install chocolatey.chocolatey
    ```

1. Copy the **nupkg** file containing the version of Chocolatey you'd like to test onto the Windows VM, under `C:\packages` (you will probably need to create this folder as well).
1. Run the following commands in an administrative session of Windows PowerShell to install Chocolatey and update it to the version you've placed in `C:\packages`:

    ```powershell
    & ([scriptblock]::Create((Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" -UseBasicParsing)))
    choco upgrade chocolatey -y -s C:\packages --pre
    ```

1. Follow the instructions from [this blog post](https://pureinfotech.com/set-static-ip-address-windows-10/) to assign the Windows VM the static IP address `10.0.0.11`
   This IP address is hard-coded into the `vagrant-inventory.winrm` file found in the `~/.ansible/collections/ansible_collections/chocolatey/chocolatey/tests/integration/targets` folder.
   If you prefer, you can modify that file in your Linux server to point to a different IP address instead.

## Running `ansible-test`

1. Before running tests, if desired, it may be a good idea to take snapshots of the client VM in VirtualBox so that it can be easily reverted for testing multiple Chocolatey versions.
   If using Vagrant, you may opt instead to just `vagrant destroy` the environment after running the tests once and re-initializing it with `vagrant up`.
1. If using Vagrant, SSH into the Ansible server with the following command:

    ```sh
    vagrant ssh choco_ansible_server
    ```

   Otherwise, open your Linux VM directly and continue from the VM terminal.
1. Run the chocolatey.chocolatey collection tests against the Windows client machine:

    ```sh
    source ~/ansible/bin/activate
    cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey
    ansible-test windows-integration -vvvv --inventory vagrant-inventory.winrm --requirements --continue-on-error
    ```

1. To retrieve the test files from the Ansible server VM when using Vagrant, copy the test result files to the `/vagrant/results` shared folder to retrieve them from the Linux VM:

    ```sh
    cp tests/output/junit/* /vagrant/results
    ```

   When not using Vagrant, you'll need to retrieve the XML files from the `/home/USERNAME/.ansible/collections/ansible_collections/chocolatey/chocolatey/tests/output/junit` folder and download them manually.

Once the tests are complete, inspect the console output to determine if there were any failures, or inspect the JUnit XML files from the test run mentioned above.
Under `PLAY RECAP*************************` in the console the overall results will be displayed.
Successful test runs will have only `ok` and `changed` results; i.e., there should be no `unreachable`, `failed`, or `skipped` results.

To view the JUnit XML reports as HTML, you can install `xunit-viewer` from NPM and collate the reports into a `html` file to view in the browser:

```powershell
npm install xunit-viewer -g
xunit-viewer -r ./results -o ./results/report.html
Invoke-Item ./results/report.html
```
