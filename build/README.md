# Build and Testing Instructions

## Continuous Integration

CI runs on GitHub Actions, defined in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).
It replaces the Azure Pipelines definition that previously built the collection and tested it against an Azure DevTest Labs VM.

The workflow has four jobs:

| Job | Runner | What it does |
| --- | --- | --- |
| `build` | `ubuntu-latest` | Stamps the version into `galaxy.yml`, builds the collection tarball, and uploads it as an artifact. |
| `sanity` | `ubuntu-latest` | Runs `ansible-test sanity` against the built collection, once per `ansible-core` version. |
| `integration` | `windows-latest` | Runs `ansible-test windows-integration` against the runner itself, once per `ansible-core` version. |
| `publish` | `ubuntu-latest` | On a tag, publishes the collection to Ansible Galaxy and Automation Hub. |

### How the integration tests get a Windows target

GitHub Actions has no equivalent of the Azure DevTest Lab that previously provided a Windows client VM, and `ansible-test` needs a POSIX control node.
Instead, a single `windows-latest` runner plays both roles:

- The runner itself is the **Ansible target**. [`Initialize-WinRmTarget.ps1`](Initialize-WinRmTarget.ps1) creates a local `ansible` administrator with a per-run random password and configures an HTTP WinRM listener on port 5985.
- A WSL distribution on that same runner is the **control node**, set up by [`Vampire/setup-wsl`](https://github.com/Vampire/setup-wsl). It reaches the Windows host on the default gateway of its NAT network.

Because the WinRM traffic never leaves the runner VM, the listener uses Basic authentication over HTTP rather than the HTTPS and CredSSP setup the Azure lab VMs used.

Unlike the Azure pipeline, which shared one VM across the matrix and therefore ran the legs one at a time, each matrix leg here gets its own runner and they all run in parallel.

### Why the runner's Chocolatey install is reset

The Azure lab VMs were close to a blank slate. GitHub-hosted Windows runners are not: they ship with Chocolatey CLI already installed, along with a number of packages, and potentially non-default configuration.

The integration tests assert on the *exact* set of installed packages, the exact list of pins, the first entry of the sources list, and default configuration and feature values. Ambient packages make those assertions meaningless, and `win_chocolatey`'s `state: latest` against `name: all` would try to upgrade whatever the image happened to ship.

[`Reset-ChocolateyState.ps1`](Reset-ChocolateyState.ps1) therefore removes the Chocolatey installation outright and reinstalls it from the community bootstrap script before the tests run, leaving only the `chocolatey` package, the default source, default config and features, and no pins. It fails the job if anything else is still installed afterwards, so a change to the runner image surfaces as a clear error rather than as confusing test failures.

Software installed *by* those packages is left on disk. Chocolatey no longer tracks it, which is all the tests care about.

### Known coverage gap: `win_chocolatey-legacy`

The `win_chocolatey-legacy` target verifies that Chocolatey CLI v2.0+ refuses to install when .NET Framework 4.8 is missing, and that v1.4.0 installs in its place. The Azure pipeline ran it against a purpose-built Windows Server lab VM.

**Every GitHub-hosted Windows image ships .NET Framework 4.8 or newer**, so the target's `when:` guard makes it a no-op there. It is excluded from the workflow rather than left to silently skip.

Running it needs a Windows host without .NET Framework 4.8, such as a self-hosted runner. Nothing in this repository sets one up any more, but the target is kept so it can still be run by hand.

### Secrets and settings the repository needs

- A `galaxy` [environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) holding the `GALAXY_API_KEY` and `AH_API_KEY` secrets. Scoping them to an environment keeps them out of every other job, and lets the organisation require a manual approval before a release is published.
- If the organisation restricts which actions may run, `Vampire/setup-wsl` needs to be allowed. It's the only third-party action, so it's pinned to a commit SHA.

## Invoke-CollectionTests.ps1

Use this file when you just want to do a one-time run through the module's tests.
It stands up the environment via Vagrant and VirtualBox, and runs the module tests.

This setup is out of date. The Ubuntu 20.04 box it uses ships Python 3.8, which can't run the ansible-core versions the collection supports (2.18 and later), so it won't match CI.

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
```

### Cleaning Up

Once done, the Vagrant environment can be destroyed at any time by `exit`-ing the SSH session and running `vagrant destroy` from the `build` directory.
