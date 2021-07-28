# Ansible Collection: chocolatey.chocolatey

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

Some example usages of the modules in this collection are below.

Upgrade all packages with Chocolatey:

```yaml
- name: Upgrade installed packages
  win_chocolatey:
    name: all
    state: latest
```

Install version 6.6 of `notepadplusplus`:

```yaml
- name: Install notepadplusplus version 6.6
  win_chocolatey:
    name: notepadplusplus
    version: '6.6'
```

Set the Chocolatey cache location:

```yaml
- name: Set the cache location
  win_chocolatey_config:
    name: cacheLocation
    state: present
    value: C:\Temp
```

Use Background Mode for Self-Service (Business Feature):

```yaml
- name: Use background mode for self-service
  win_chocolatey_feature:
    name: useBackgroundService
    state: enabled
```

Remove the Community Package Repository (as you have an internal repository; recommended):

```yaml
- name: Disable Community Repo
  win_chocolatey_source:
    name: chocolatey
    state: absent
```

## Testing and Development

If you want to develop new content for this collection or improve what's already here, the easiest way to work on the collection is to clone it into one of the configured [`COLLECTIONS_PATHS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#collections-paths), and work on it there.

### Testing with `ansible-test`

The `tests` directory contains configuration for running integration tests using [`ansible-test`](https://docs.ansible.com/ansible/latest/dev_guide/testing_integration.html).

You can run the collection's test suites with the commands:

```code
ansible-test windows-integration --docker -v --color
```

## License

GPL v3.0 License

See [LICENSE](LICENSE) to see full text.

<!-- Link Targets -->

[pipeline-link]: https://dev.azure.com/ChocolateyCI/Chocolatey-Ansible/_build/latest?definitionId=2&branchName=master
[pipeline-badge]: https://dev.azure.com/ChocolateyCI/Chocolatey-Ansible/_apis/build/status/Chocolatey%20Collection%20CI?branchName=master

## Submitting Issues

Observe the following help for submitting an issue:

Prerequisites:

 * The issue has to do with the Chocolatey Ansible collection itself and is not a package, Chocolatey or website issue.
 * Please check to see if your issue already exists with a quick search of the issues. Start with one relevant term and then add if you get too many results.
 * You are not submitting an "Enhancement". Enhancements should observe [CONTRIBUTING](https://github.com/chocolatey/chocolatey-ansible/blob/master/CONTRIBUTING.md) guidelines.
 * You are not submitting a question - questions are better served as [discussions](https://github.com/chocolatey/chocolatey-ansible/discussions).
 * Please make sure you've read over and agree with the [etiquette regarding communication](#etiquette-regarding-communication).

Submitting a ticket:

 * We'll need debug and verbose output, so please run and capture the log with `-vvvv`. You can submit that with the issue or create a gist and link it.
 * **Please note** that the verbose output may have sensitive data (passwords or api keys), so please remove those if they are there prior to submitting the issue.
 * choco.exe logs to a file in `$env:ChocolateyInstall\log\`. You can grab the Chocolatey specific log output from there so you don't have to capture or redirect screen output. Please limit the amount included to just the command run (the log is appended to with every command).
 * Please save the log output in a [gist](https://gist.github.com) (save the file as `log.sh`) and link to the gist from the issue. Feel free to create it as secret so it doesn't fill up against your public gists. Anyone with a direct link can still get to secret gists. If you accidentally include secret information in your gist, please delete it and create a new one (gist history can be seen by anyone) and update the link in the ticket (issue history is not retained except by email - deleting the gist ensures that no one can get to it). Using gists this way also keeps accidental secrets from being shared in the ticket in the first place as well.
 * We'll need the entire log output from the run, so please don't limit it down to areas you feel are relevant. You may miss some important details we'll need to know. This will help expedite issue triage.
 * It's helpful to include the version of choco, the version of the OS, and the version of PowerShell (Posh).
 * Include screenshots and / or animated gifs whenever possible, they help show us exactly what the problem is.

## Etiquette Regarding Communication

If you are an open source user requesting support, please remember that most folks in the Chocolatey community are volunteers that have lives outside of open source and are not paid to ensure things work for you, so please be considerate of others' time when you are asking for things. Many of us have families that also need time as well and only have so much time to give on a daily basis. A little consideration and patience can go a long way.