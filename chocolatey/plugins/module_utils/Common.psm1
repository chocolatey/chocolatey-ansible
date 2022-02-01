#AnsibleRequires -CSharpUtil Ansible.Basic

$script:module = $null

function New-AnsibleModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Specifications,

        [Parameter(Mandatory = $true)]
        $Arguments
    )

    $script:module = [Ansible.Basic.AnsibleModule]::Create($Arguments, $Specifications)
    $script:module
}

function Get-AnsibleModule {
    [CmdletBinding()]
    param()

    $script:module
}

function Get-ChocolateyCommand {
    [CmdletBinding()]
    param(
        # If provided, does not terminate the task run when choco.exe is not found.
        [Parameter()]
        [switch]
        $IgnoreMissing
    )

    $command = Get-Command -Name choco.exe -CommandType Application -ErrorAction SilentlyContinue

    if (-not $command) {
        $installDir = if ($env:ChocolateyInstall) {
            $env:ChocolateyInstall
        }
        else {
            "$env:SYSTEMDRIVE\ProgramData\Chocolatey"
        }

        $command = Get-Command -Name "$installDir\bin\choco.exe" -CommandType Application -ErrorAction SilentlyContinue

        if (-not ($command -or $IgnoreMissing)) {
            $message = "Failed to find Chocolatey installation, make sure choco.exe is in the PATH env value"
            Assert-TaskFailed -Message $message
        }
    }

    $command
}

function Assert-TaskFailed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [Parameter()]
        [Ansible.Basic.AnsibleModule]
        $Module = (Get-AnsibleModule),

        [Parameter()]
        [string]
        $Command,

        [Parameter()]
        [hashtable]
        $CommandResult,

        [Parameter()]
        [Exception]
        $Exception
    )

    if ($null -ne $CommandResult) {
        $resultKeys = 'rc', 'stdout', 'stderr'

        foreach ($key in $resultKeys) {
            $Module.Result.$key = $CommandResult.$key
        }
    }

    if ($null -ne $Command) {
        $Module.Result.command = $Command
    }

    if ($null -ne $Exception) {
        $Module.FailJson($Message, $Exception)
    }
    else {
        $Module.FailJson($Message)
    }
}

function Get-StdoutLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $CommandResult
    )

    $result.stdout.Trim().Split(
        [System.Environment]::NewLine,
        [System.StringSplitOptions]::RemoveEmptyEntries
    )
}

function Set-TaskResultChanged {
    [CmdletBinding()]
    param(
        [Parameter()]
        [Ansible.Basic.AnsibleModule]
        $Module = (Get-AnsibleModule)
    )

    $Module.Result.changed = $true
}
