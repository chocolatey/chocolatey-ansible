#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil

#AnsibleRequires -PowerShell ..module_utils.Common

# As of chocolatey 0.9.10, non-zero success exit codes can be returned
# See https://github.com/chocolatey/choco/issues/512#issuecomment-214284461
$script:successExitCodes = (0, 1605, 1614, 1641, 3010)

function Get-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter()]
        [string]
        $Version
    )

    $command = Argv-ToString -Arguments @(
        $ChocoCommand.Path
        "list"
        "--local-only"
        "--limit-output"

        if ($Version) {
            '--version', $Version
        }
        else {
            '--all-versions'
        }
    )
    $result = Run-Command -Command $command

    # Chocolatey v0.10.12 introduced enhanced exit codes, 2 means no results, e.g. no package
    if ($result.rc -notin @(0, 2)) {
        $module.Result.command = $command
        $message = 'Error checking installation status for chocolatey packages'
        Assert-TaskFailed -Message $message
    }

    $result.stdout.Trim().Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries) |
        ForEach-Object {
            # Sanity check in case additional output is added in the future.
            if ($_.Contains('|')) {
                $package, $version, $null = $_.Split('|')

                @{
                    package = $package
                    version = $version
                }
            }
        }
}

function Get-ChocolateyPackageVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Version
    )

    begin {
        $versionSplat = if ([string]::IsNullOrEmpty($Version)) { @{} } else { @{ Version = $Version } }

        # Due to https://github.com/chocolatey/choco/issues/1843, we get a list of all the installed packages and
        # filter it ourselves. This has the added benefit of being quicker when dealing with multiple packages as we
        # only call choco.exe once.
        $installedPackages = Get-ChocolateyPackage @versionSplat -ChocoCommand $ChocoCommand

        # Create a hashtable that will store our package version info.
        $results = @{}
    }
    process {
        if ($Name -eq 'all') {
            # All is a special package name that means all installed packages, we set a dummy version so absent, latest
            # and downgrade will run with all.
            $results.'all' = @('0.0.0')
        }
        else {
            $packageInfo = $installedPackages | Where-Object { $_.package -eq $Name }
            if ($null -eq $packageInfo) {
                $results.$Name = $null
            }
            else {
                $results.$Name = @($packageInfo.version)
            }
        }
    }
    end {
        $results
    }
}

function Get-CommonChocolateyArguments {
    # uses global vars like check_mode and verbosity to control the common args
    # run with Chocolatey
    "--yes"
    "--no-progress"

    # global vars that control the arguments
    if ($module.CheckMode) {
        "--what-if"
    }

    if ($module.Verbosity -ge 4) {
        if ($module.Verbosity -ge 5) {
            "--debug"
        }

        "--verbose"
    }
    elseif ($module.Verbosity -le 2) {
        "--limit-output"
    }
}

function Get-InstallChocolateyArguments {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]
        $AllowDowngrade,

        [Parameter()]
        [switch]
        $AllowEmptyChecksums,

        [Parameter()]
        [switch]
        $AllowMultiple,

        [Parameter()]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [string]
        $Architecture,

        [Parameter()]
        [string[]]
        $ChocoArgs,

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [switch]
        $IgnoreChecksums,

        [Parameter()]
        [switch]
        $IgnoreDependencies,

        [Parameter()]
        [string]
        $InstallArgs,

        [Parameter()]
        [switch]
        $OverrideArgs,

        [Parameter()]
        [string]
        $PackageParams,

        [Parameter()]
        [string]
        $ProxyUrl,

        [Parameter()]
        [string]
        $ProxyUsername,

        [Parameter()]
        [string]
        $ProxyPassword,

        [Parameter()]
        [bool]
        $SkipScripts,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $SourceUsername,

        [Parameter()]
        [string]
        $SourcePassword,

        [Parameter()]
        [int]
        $Timeout,

        [Parameter()]
        [string]
        $Version
    )

    "--fail-on-unfound"

    # Include common arguments for installing/updating a Chocolatey package
    Get-CommonChocolateyArguments

    if ($AllowDowngrade) { "--allow-downgrade" }
    if ($AllowEmptyChecksums) { "--allow-empty-checksums" }
    if ($AllowMultiple) { "--allow-multiple" }
    if ($AllowPrerelease) { "--prerelease" }
    if ($Architecture -eq "x86") { "--x86" }
    if ($Force) { "--force" }
    if ($IgnoreChecksums) { "--ignore-checksums" }
    if ($IgnoreDependencies) { "--ignore-dependencies" }
    if ($InstallArgs) { "--install-arguments", $InstallArgs }
    if ($OverrideArgs) { "--override-arguments" }
    if ($PackageParams) { "--package-parameters", $PackageParams }
    if ($ProxyUrl) { "--proxy", $ProxyUrl }
    if ($ProxyUsername) { "--proxy-user", $ProxyUsername }
    if ($ProxyPassword) { "--proxy-password", $ProxyPassword }
    if ($SkipScripts) { "--skip-scripts" }
    if ($Source) { "--source", $Source }

    if ($SourceUsername) {
        "--user", $SourceUsername
        "--password", $SourcePassword
    }

    if ($PSBoundParameters.ContainsKey('Timeout')) { "--timeout", $Timeout }
    if ($Version) { "--version", $Version }
    if ($ChocoArgs) { $ChocoArgs }
}

function Get-ChocolateyPin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand
    )

    $command = Argv-ToString -Arguments @(
        $ChocoCommand.Path
        "pin", "list"
        "--limit-output"
    )
    $result = Run-Command -Command $command

    if ($result.rc -ne 0) {
        Assert-TaskFailed -Message "Error getting list of pinned packages" -Command $command
    }

    $pins = @{}

    $result | Get-StdoutLines | ForEach-Object {
        $package, $version, $null = $_.Split('|')

        if ($pins.ContainsKey($package)) {
            $pins.$package.Add($version)
        }
        else {
            $pins.$package = [System.Collections.Generic.List[string]]@( $version )
        }
    }

    $pins
}

function Set-ChocolateyPin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [switch]
        $Pin,

        [Parameter()]
        [string]
        $Version
    )

    if ($Pin) {
        $action = "add"
        $errorMessage = "Error pinning package '$name'"
    }
    else {
        $action = "remove"
        $errorMessage = "Error unpinning package '$name'"
    }

    $arguments = @(
        $ChocoCommand.Path,
        "pin", $action
        "--name", $name

        if ($Version) {
            $errorMessage = "$errorMessage at '$Version'"
            "--version", $Version
        }

        Get-CommonChocolateyArguments
    )

    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command
    if ($result.rc -ne 0) {
        Assert-TaskFailed -Message $errorMessage -CommandResult $result -Command $command
    }

    Set-TaskResultChanged
}

function Update-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Package,

        [Parameter()]
        [Ansible.Basic.AnsibleModule]
        $Module = (Get-AnsibleModule),

        [Parameter()]
        [switch]
        $AllowDowngrade,

        [Parameter()]
        [switch]
        $AllowEmptyChecksums,

        [Parameter()]
        [switch]
        $AllowMultiple,

        [Parameter()]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [string]
        $Architecture,

        [Parameter()]
        [string[]]
        $ChocoArgs,

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [switch]
        $IgnoreChecksums,

        [Parameter()]
        [switch]
        $IgnoreDependencies,

        [Parameter()]
        [string]
        $InstallArgs,

        [Parameter()]
        [switch]
        $OverrideArgs,

        [Parameter()]
        [string]
        $PackageParams,

        [Parameter()]
        [string]
        $ProxyUrl,

        [Parameter()]
        [string]
        $ProxyUsername,

        [Parameter()]
        [string]
        $ProxyPassword,

        [Parameter()]
        [bool]
        $SkipScripts,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $SourceUsername,

        [Parameter()]
        [string]
        $SourcePassword,

        [Parameter()]
        [int]
        $Timeout,

        [Parameter()]
        [string]
        $Version
    )

    $commonParams = $PSBoundParameters -as [hashtable]
    $commonParams.Remove('Package')
    $commonParams.Remove('ChocoCommand')
    if ($PSBoundParameters.ContainsKey('Module')) {
        $commonParams.Remove('Module')
    }

    $arguments = @(
        $ChocoCommand.Path
        "upgrade"
        $Package
        Get-InstallChocolateyArguments @commonParams
    )

    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command
    $Module.Result.rc = $result.rc

    if ($res.rc -notin $script:successExitCodes) {
        $message = "Error updating package(s) '$($Package -join ", ")'"
        Assert-TaskFailed -Message $message -Command $command -CommandResult $result
    }

    if ($Module.Verbosity -gt 1) {
        $Module.Result.stdout = $result.stdout
    }

    if ($result.stdout -match ' upgraded (\d+)/\d+ package') {
        if ($matches[1] -gt 0) {
            Set-TaskResultChanged
        }
    }

    # Need to set to false in case the rc is not 0 and a failure didn't actually occur
    $Module.Result.failed = $false
}

function Install-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Package,

        [Parameter()]
        [Ansible.Basic.AnsibleModule]
        $Module = (Get-AnsibleModule),

        [Parameter()]
        [switch]
        $AllowDowngrade,

        [Parameter()]
        [switch]
        $AllowEmptyChecksums,

        [Parameter()]
        [switch]
        $AllowMultiple,

        [Parameter()]
        [switch]
        $AllowPrerelease,

        [Parameter()]
        [string]
        $Architecture,

        [Parameter()]
        [string[]]
        $ChocoArgs,

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [switch]
        $IgnoreChecksums,

        [Parameter()]
        [switch]
        $IgnoreDependencies,

        [Parameter()]
        [string]
        $InstallArgs,

        [Parameter()]
        [switch]
        $OverrideArgs,

        [Parameter()]
        [string]
        $PackageParams,

        [Parameter()]
        [string]
        $ProxyUrl,

        [Parameter()]
        [string]
        $ProxyUsername,

        [Parameter()]
        [string]
        $ProxyPassword,

        [Parameter()]
        [bool]
        $SkipScripts,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $SourceUsername,

        [Parameter()]
        [string]
        $SourcePassword,

        [Parameter()]
        [int]
        $Timeout,

        [Parameter()]
        [string]
        $Version
    )

    $commonParams = $PSBoundParameters -as [hashtable]
    $commonParams.Remove('Package')
    $commonParams.Remove('ChocoCommand')
    if ($PSBoundParameters.ContainsKey('Module')) {
        $commonParams.Remove('Module')
    }

    $arguments = @(
        $ChocoCommand.Path
        "install"
        $Package
        Get-InstallChocolateyArguments @commonParams
    )

    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command
    $Module.Result.rc = $result.rc

    if ($res.rc -notin $script:successExitCodes) {
        $message = "Error installing package(s) '$($Package -join ", ")'"
        Assert-TaskFailed -Message $message -Command $command -CommandResult $result
    }

    if ($Module.Verbosity -gt 1) {
        $Module.Result.stdout = $result.stdout
    }

    Set-TaskResultChanged

    # need to set to false in case the rc is not 0 and a failure didn't actually occur
    $Module.Result.failed = $false
}

function Uninstall-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandInfo]
        $ChocoCommand,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Package,

        [Parameter()]
        [Ansible.Basic.AnsibleModule]
        $Module = (Get-AnsibleModule),

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [string]
        $PackageParams,

        [Parameter()]
        [switch]
        $SkipScripts,

        [Parameter()]
        [switch]
        $RemoveDependencies,

        [Parameter()]
        [switch]
        $AllowMultiple,

        [Parameter()]
        [int]
        $Timeout,

        [Parameter()]
        [string]
        $Version
    )

    $arguments = @(
        $ChocoCommand.Path
        "uninstall"
        $Package
        Get-CommonChocolateyArguments

        if ($Version) {
            "--version", $Version

            if ($AllowMultiple) {
                "--allow-multiple"
            }
        }
        else {
            "--all-versions"
        }

        if ($RemoveDependencies) { "--remove-dependencies" }
        if ($Force) { "--force" }
        if ($PSBoundParameters.ContainsKey('Timeout')) { "--timeout", $timeout }
        if ($SkipScripts) { "--skip-scripts" }
        if ($PackageParams) { "--package-parameters", $package_params }
    )

    $command = Argv-ToString -Arguments $arguments
    $result = Run-Command -Command $command
    $Module.Result.rc = $result.rc

    if ($res.rc -notin $script:successExitCodes) {
        $message = "Error uninstalling package(s) '$($Package -join ", ")'"
        Assert-TaskFailed -Message $message -Command $command -CommandResult $result
    }

    if ($Module.Verbosity -gt 1) {
        $Module.Result.stdout = $result.stdout
    }

    Set-TaskResultChanged

    # need to set to false in case the rc is not 0 and a failure didn't actually occur
    $Module.Result.failed = $false
}

function Install-Chocolatey {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $ProxyUrl,

        [Parameter()]
        [string]
        $ProxyUsername,

        [Parameter()]
        [string]
        $ProxyPassword,

        [Parameter()]
        [string]
        $Source,

        [Parameter()]
        [string]
        $SourceUsername,

        [Parameter()]
        [string]
        $SourcePassword,

        [Parameter()]
        [string]
        $Version,

        [Parameter()]
        [switch]
        $SkipWarning
    )

    $chocoCommand = Get-ChocolateyCommand -IgnoreMissing
    if ($null -eq $chocoCommand) {
        # We need to install chocolatey
        # Enable TLS1.1/TLS1.2 if they're available but disabled (eg. .NET 4.5)
        $protocols = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::SystemDefault

        if ([System.Net.SecurityProtocolType].GetMember("Tls11").Count -gt 0) {
            $protocols = $protocols -bor [System.Net.SecurityProtocolType]::Tls11
        }

        if ([System.Net.SecurityProtocolType].GetMember("Tls12").Count -gt 0) {
            $protocols = $protocols -bor [System.Net.SecurityProtocolType]::Tls12
        }

        [System.Net.ServicePointManager]::SecurityProtocol = $protocols

        # These env values are used in the install.ps1 script when getting
        # external dependencies
        $environment = [Environment]::GetEnvironmentVariables()
        $client = New-Object -TypeName System.Net.WebClient

        if ($ProxyUrl) {
            $environment.chocolateyProxyLocation = $ProxyUrl

            $proxy = New-Object -TypeName System.Net.WebProxy -ArgumentList $ProxyUrl, $true
            $client.Proxy = $proxy

            if ($ProxyUsername -and $ProxyPassword) {
                $environment.chocolateyProxyUser = $ProxyUsername
                $environment.chocolateyProxyPassword = $ProxyPassword
                $securePassword = ConvertTo-SecureString -String $ProxyPassword -AsPlainText -Force
                $proxy.Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @(
                    $ProxyUsername
                    $securePassword
                )
            }
        }

        if ($Version) {
            # Set the chocolateyVersion environment variable when bootstrapping Chocolatey to install that specific
            # version.
            $environment.chocolateyVersion = $Version
        }

        $scriptUrl = if ($Source) {
            $uriInfo = [System.Uri]$Source

            # check if the URL already contains the path to PS script
            if ($Source -like "*.ps1") {
                $Source
            }
            elseif ($uriInfo.AbsolutePath -like '/repository/*') {
                # Best-effort guess at finding an install.ps1 for Chocolatey in the given repository
                "$($uriInfo.Scheme)://$($uriInfo.Authority)/$($uriInfo.AbsolutePath)/install.ps1" -replace '(?<!:)//', '/'
            }
            else {
                # chocolatey server automatically serves a script at http://host/install.ps1, we rely on this
                # behaviour when a user specifies the choco source URL and it doesn't look like a repository
                # style url.
                # If a custom URL or file path is desired, they should use win_get_url/win_shell manually.
                # We need to strip the path off the URL and append `install.ps1`
                "$($uriInfo.Scheme)://$($uriInfo.Authority)/install.ps1"
            }

            if ($SourceUsername) {
                # While the choco-server does not require creds on install.ps1, Net.WebClient will only send the
                # credentials if the initial request fails; we add the creds here in case the source URL is not
                # choco-server and requires authentication.
                $securePassword = ConvertTo-SecureString -String $SourcePassword -AsPlainText -Force
                $client.Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @(
                    $SourceUsername
                    $securePassword
                )
            }
        }
        else {
            "https://community.chocolatey.org/install.ps1"
        }

        try {
            $installScript = $client.DownloadString($scriptUrl)
        }
        catch {
            $message = "Failed to download Chocolatey script from '$scriptUrl'; $($_.Exception.Message)"
            Assert-TaskFailed -Message $message -Exception $_
        }

        if (-not $module.CheckMode) {
            $scriptFile = New-Item -Path (Join-Path $module.TmpDir -ChildPath 'chocolateyInstall.ps1') -ItemType File
            $installScript | Set-Content -Path $scriptFile

            # These commands will be sent over stdin for the PowerShell process, and will be read line by line,
            # so we must join them on \r\n line-feeds to have them read as separate commands.
            $commands = @(
                '$ProgressPreference = "SilentlyContinue"'
                '& "{0}"' -f $scriptFile
            ) -join "`r`n"

            $result = Run-Command -Command "powershell.exe -" -Stdin $commands -Environment $environment
            if ($result.rc -ne 0) {
                $message = "Chocolatey bootstrap installation failed."
                Assert-TaskFailed -Message $message -CommandResult $result
            }

            if (-not $SkipWarning) {
                $module.Warn("Chocolatey was missing from this system, so it was installed during this task run.")
            }
        }

        Set-TaskResultChanged

        # locate the newly installed choco.exe
        $chocoCommand = Get-ChocolateyCommand -IgnoreMissing
    }

    if ($null -eq $chocoCommand -or -not (Test-Path -LiteralPath $chocoCommand.Path)) {
        if ($module.CheckMode) {
            $module.Result.skipped = $true
            $module.Result.msg = "Skipped check mode run on win_chocolatey as choco.exe cannot be found on the system"
            $module.ExitJson()
        }
        else {
            $message = "Failed to find choco.exe, make sure it is added to the PATH or the env var 'ChocolateyInstall' is set"
            Assert-TaskFailed -Message $message
        }
    }

    $actualVersion = @(Get-ChocolateyPackageVersion -ChocoCommand $chocoCommand -Name 'chocolatey')[0]
    try {
        # The Chocolatey version may not be in the strict form of major.minor.build and will fail to cast to
        # System.Version. We want to warn if this is the case saying module behaviour may be incorrect.
        $actualVersion = [Version]$actualVersion
    }
    catch {
        $module.Warn("Failed to parse Chocolatey version '$actualVersion' for checking module requirements, module may not work correctly: $($_.Exception.Message)")
        $actualVersion = $null
    }

    if ($null -ne $actualVersion -and $actualVersion -lt [Version]"0.10.5") {
        if ($module.CheckMode) {
            $module.Result.skipped = $true
            $module.Result.msg = "Skipped check mode run on win_chocolatey as choco.exe is too old, a real run would have upgraded the executable. Actual: '$actualVersion', Minimum Version: '0.10.5'"
            $module.ExitJson()
        }

        $module.Warn("Chocolatey was older than v0.10.5 so it will be upgraded during this task run.")
        $params = @{
            ChocoCommand   = $chocoCommand
            Packages       = @("chocolatey")
            ProxyUrl       = $ProxyUrl
            ProxyUsername  = $ProxyUsername
            ProxyPassword  = $ProxyPassword
            Source         = $Source
            SourceUsername = $SourceUsername
            SourcePassword = $SourcePassword
        }
        Update-ChocolateyPackage @params
    }

    $chocoCommand
}
