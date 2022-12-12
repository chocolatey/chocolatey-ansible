[CmdletBinding()]
param()
begin {
    Push-Location

    $InventoryFile = 'vagrant-inventory.winrm'

#region Bash Commands
    # All command strings in this region must be valid Bash command lines; the lines following this region join
    # the provided commands into a single command string.
    $ImportVenv = '. ~/ansible-venv/bin/activate'
    $SetupCommands = @(
        $ImportVenv
        'cd chocolatey'

        # Skip building collection in CI; this will have been done already by a previous CI step.
        if (-not $IsCIBuild) {
            'ansible-galaxy collection build'
        }

        'ansible-galaxy collection install *.tar.gz'
        'ansible-galaxy collection install ansible.windows'

        'cd ~/.ansible/collections/ansible_collections/chocolatey/chocolatey'
        "mv -f tests/integration/$InventoryFile tests/integration/inventory.winrm"

        'sudo pip3 install -U pywinrm'
        'sudo pip3 install -U requests.credssp'
    )
#endregion

    # Join these with && so if the setup fails, the tests don't try to run
    $Commands = $SetupCommands -join ' && '
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
    }
    finally {
        Pop-Location
    }
}
