[CmdletBinding()]
param(
    # Select only a single target for integration tests to run only a portion of the tests.
    [Parameter()]
    [ValidateSet('win_chocolatey', 'win_chocolatey_config', 'win_chocolatey_facts', 'win_chocolatey_feature', 'win_chocolatey_source', 'win_chocolatey-legacy')]
    [string]
    $TestTarget
)
begin {
    Push-Location

    $InventoryFile = 'vagrant-inventory.winrm'
    $OutputPath = '~/.testresults/'

#region Bash Commands
    # All command strings in this region must be valid Bash command lines; the lines following this region join
    # the provided commands into a single command string.
    $ImportVenv = '. ~/ansible-venv/bin/activate'
    $SetCollectionLocation = 'cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey'
    $SetupCommands = @(
        $ImportVenv
        'cd chocolatey'

        'ansible-galaxy collection build'
        'ansible-galaxy collection install *.tar.gz'

        # Vagrant has issues installing this as part of the provisioning step for some reason.
        'ansible-galaxy collection install ansible.windows'
    )
    $TestCommands = @(
        $SetCollectionLocation
        $ImportVenv

        "mv -f tests/integration/$InventoryFile tests/integration/inventory.winrm"

        if (-not $TestTarget) {
            "sudo ansible-test windows-integration -vvv --requirements --continue-on-error --exclude win_chocolatey-legacy"
            "sudo ansible-test sanity -vvvvv --requirements"
        }
        else {
            "sudo ansible-test windows-integration $TestTarget -vvv --requirements --continue-on-error"
        }
    )
    $CleanupCommands = @(
        "cp -r ./tests/output/ $OutputPath"
        "rm -r $OutputPath/.tmp 2> /dev/null"
    )
#endregion

    # Join these with && so if the setup fails, the tests don't try to run
    $Commands = @(
        $SetupCommands
        # Join these with ; so if an individual step fails, continue to run so we can get as many results as possible
        @(
            $TestCommands
            $CleanupCommands
        ) -join ' ; '
    ) -join ' && '
}
process {
    try {
        Set-Location -Path $PSScriptRoot
        vagrant up

        if (-not $?) {
            throw "An error has occurred; please refer to the Vagrant log for details."
        }

        if (-not $env:PACKAGE_VERSION) {
            $env:PACKAGE_VERSION = '1.0.0'
        }

        vagrant ssh choco_ansible_server --command "sed -i 's/{{ REPLACE_VERSION }}/$env:PACKAGE_VERSION/g' ./chocolatey/galaxy.yml"
        vagrant ssh choco_ansible_server --command $Commands

        vagrant destroy --force
    }
    finally {
        Pop-Location
    }
}
