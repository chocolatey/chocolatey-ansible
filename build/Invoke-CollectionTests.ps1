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
    $Secret
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
    $ImportVenv = 'source ~/ansible-venv/bin/activate'
    $SetCollectionLocation = 'cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey'
    $SetupCommands = @(
        $ImportVenv
        'cd ./chocolatey'

        # Skip building collection in CI; this will have been done already by a previous CI step.
        if (-not $IsCIBuild) {
            'ansible-galaxy collection build'
        }

        'ansible-galaxy collection install *.tar.gz'
    )
    $TestCommands = @(
        $SetCollectionLocation
        $ImportVenv

        if ($IsCIBuild) {
            # Move the CI inventory file into the collection for testing
            "mv -f ~/$InventoryFile ./tests/integration/inventory.winrm"
        }
        else {
            "mv -f ./tests/integration/$InventoryFile ./tests/integration/inventory.winrm"
        }

        "${Sudo}ansible-test windows-integration -vvv --requirements --continue-on-error"
        "${Sudo}ansible-test sanity -vvvvv --requirements"
        "${Sudo}ansible-test coverage xml -vvvvv --requirements"
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
                "ansible_winrm_transport=ntlm"
                "ansible_winrm_server_cert_validation=ignore"
                "ansible_become_method=runas"
            ) -join "`n"

            $Inventory | Set-Content -Path "~/$InventoryFile" -Force

            bash -c $Commands
        }
        else {
            Set-Location -Path $PSScriptRoot
            vagrant up

            if (-not $?) {
                throw "An error has occurred; please refer to the Vagrant log for details."
            }

            if (-not $env:PACKAGE_VERSION) {
                $env:PACKAGE_VERSION = '24.6.26'
            }

            vagrant ssh choco_ansible_server --command "sed -i ./chocolatey/galaxy.yml 's/{{ REPLACE_VERSION }}/$env:PACKAGE_VERSION/g'"
            vagrant ssh choco_ansible_server --command $Commands
            $Result = [PSCustomObject]@{
                Success  = $?
                ExitCode = $LASTEXITCODE
            }

            vagrant destroy --force

            $Result

            if (-not $Result.Success) {
                throw "Test failures occurred. Refer to the Vagrant log."
            }
        }
    }
    finally {
        Pop-Location
    }
}
