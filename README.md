# Ansible Collection: choclatey.chocolatey

|                   Build Status                   |
| :----------------------------------------------: |
| [![Build Status][pipeline-badge]][pipeline-link] |

This repo hosts the `chocolatey.chocolatey` Ansible Collection.

The collection includes the modules required to configure Chocolatey, as well as manage packages on Windows using Chocolatey.

## Installation and Usage

### Installing the Collection from Ansible Galaxy

Before using the Chocolatey collection, you need to install it with the `ansible-galaxy` CLI:

    ansible-galaxy collection install chocolatey.chocolatey

You can also include it in a `requirements.yml` file and install it via `ansible-galaxy collection install -r requirements.yml` using the format:

```yaml
collections:
- name: chocolatey.chocolatey
```

### Modules

This collection provides the following modules you can use in your own roles:

| Name                          | Description                               |
|-------------------------------|-------------------------------------------|
|`win_chocolatey`               | Manage packages using chocolatey          |  
|`win_chocolatey_config`        | Manage Chocolatey config settings         |
|`win_chocolatey_facts`         | Create a facts collection for Chocolatey  |
|`win_chocolatey_feature`       | Manage Chocolatey features                |
|`win_chocolatey_source`        | Manage Chocolatey sources                 |

### Examples

TBD

## Developing

### Building Locally

TBD

<!-- Link Targets -->

[pipeline-link]: https://dev.azure.com/ChocolateyCI/Chocolatey-Ansible/_build/latest?definitionId=2&branchName=master
[pipeline-badge]: https://dev.azure.com/ChocolateyCI/Chocolatey-Ansible/_apis/build/status/Chocolatey%20Collection%20CI?branchName=master
