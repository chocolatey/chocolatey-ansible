[CmdletBinding(DefaultParameterSetName = 'Vagrant')]
param(
    [Parameter(ParameterSetName = 'CI')]
    [switch]
    $IsCIBuild,

    [Parameter(ParameterSetName = 'CI')]
    [string]
    $Username,

    [Parameter(ParameterSetName = 'CI')]
    [Alias('LabVMFqdn')]
    [string]
    $ComputerName,

    [Parameter(ParameterSetName = 'CI')]
    [Alias('Password')]
    [string]
    $Secret,

    # Select only a single target for integration tests to run only a portion of the tests.
    [Parameter(ParameterSetName = 'Vagrant')]
    [ValidateSet('win_chocolatey', 'win_chocolatey_config', 'win_chocolatey_facts', 'win_chocolatey_feature', 'win_chocolatey_source')]
    [string]
    $TestTarget
)
begin {
    Push-Location

    $InventoryFile, $Sudo, $OutputPath = if ($IsCIBuild) {
        'ci-inventory.winrm'
        [string]::Empty
        Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath 'testresults/'
    }
    else {
        'vagrant-inventory.winrm'
        "sudo "
        '~/.testresults/'
    }

#region Bash Commands
    # All command strings in this region must be valid Bash command lines; the lines following this region join
    # the provided commands into a single command string.
    $ImportVenv = '. ~/ansible-venv/bin/activate'
    $SetCollectionLocation = 'cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey'
    $SetupCommands = @(
        $ImportVenv
        'cd chocolatey'

        # Skip building collection in CI; this will have been done already by a previous CI step.
        if (-not $IsCIBuild) {
            'ansible-galaxy collection build'
        }

        'ansible-galaxy collection install *.tar.gz'

        if (-not $IsCIBuild) {
            # CI works fine doing this in the dependencies.sh, but Vagrant has issues doing that for
            # some reason.
            'ansible-galaxy collection install ansible.windows'
        }
    )
    $TestCommands = @(
        $SetCollectionLocation
        $ImportVenv

        if ($IsCIBuild) {
            # Move the CI inventory file into the collection for testing
            "mv -f ~/$InventoryFile ./tests/integration/inventory.winrm"
        }
        else {
            "mv -f tests/integration/$InventoryFile tests/integration/inventory.winrm"
        }

        if (-not $TestTarget) {
            "${Sudo}ansible-test windows-integration -vvv --requirements --continue-on-error"
            "${Sudo}ansible-test sanity -vvvvv --requirements"
            "${Sudo}ansible-test coverage xml -vvvvv --requirements"
        }
        else {
            "${Sudo}ansible-test windows-integration $TestTarget -vvv --requirements --continue-on-error"
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
        if ($IsCIBuild) {
            if (!$Secret) {
                Write-Warning "Choco Client Password appears to be missing!"
            }

            $Inventory = @(
                "[windows]"
                "win10 ansible_host=$ComputerName"
                ""
                "[windows:vars]"
                "ansible_user=$Username"
                "ansible_password=$Secret"
                "ansible_connection=winrm"
                "ansible_port=5986"
                "ansible_winrm_transport=credssp"
                "ansible_winrm_server_cert_validation=ignore"
                "ansible_become_method=runas"
            ) -join "`n"

            $Inventory | Set-Content -Path "~/$InventoryFile" -Force

            bash -c $Commands

            $Result = [PSCustomObject]@{
                Success  = $?
                ExitCode = $LASTEXITCODE
            }

            $Result | Out-String | Write-Host

            if (-not $Result.Success) {
                throw "Test failures occurred. Refer to the logs and test results."
            }
        }
        else {
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
    }
    finally {
        Pop-Location
    }
}
