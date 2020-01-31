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
    $ComputerName
)
begin {
    Push-Location

    $InventoryFile = if ($IsCIBuild) { 'ci-inventory.winrm' } else { 'vagrant-inventory.winrm' }
    $Command = @(
        'source ./ansible-venv/bin/activate'
        'cd ./chocolatey'
        'ansible-galaxy collection build'
        'ansible-galaxy collection install *.tar.gz'
        'cd ../.ansible/collections/ansible_collections/chocolatey/chocolatey'
        "sudo ansible-test windows-integration -vvvvv --inventory $InventoryFile"
        'cp -r ./tests/output/ ~/.testresults/'
    ) -join ';'
}
process {
    try {
        if ($IsCIBuild) {
            $Inventory = @(
                "[windows]"
                "win10 ansible_host=$ComputerName"
                ""
                "[windows:vars]"
                "ansible_user=$Username"
                "ansible_password=$env:CHOCOCICLIENT_PASSWORD"
                "ansible_connection=winrm"
                "ansible_port=5985"
                "ansible_winrm_transport=http"
                "ansible_become_method=runas"
            )

            $Inventory | Set-Content -Path './chocolatey/tests/integration/ci-inventory.winrm'
            bash -c $Command
        }
        else {
            Set-Location -Path $PSScriptRoot
            vagrant up

            if (-not $?) {
                throw "An error has occurred; please refer to the Vagrant log for details."
            }

            vagrant ssh choco_ansible_server --command $Command
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
