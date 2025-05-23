# SteamLibrarian.ps1
#Requires -Version 5.0

<#
.SYNOPSIS
SteamLibrarian - Advanced Steam Game Management Tool for Windows PowerShell

.DESCRIPTION
This PowerShell script provides comprehensive functionality to manage your Steam game library including:
- Searching and discovering installed games by AppID or name
- Retrieving detailed game information from Steam (install location, executable paths, etc.)
- Launching games via Steam protocol with optional parameters
- Monitoring game processes from launch to exit
- Direct pass-through mode to quickly find and launch games without interaction
- Easy display of game metadata and system integration details
- Multiple Steam account management and switching capabilities

SteamLibrarian works with native Steam installations on Windows without requiring
additional software or external web services.

.PARAMETER AppId
The Steam AppID of the game to manage. This is a unique identifier assigned by
Steam to each game in its catalog.

.PARAMETER GameName
Search for a game by name (partial name is supported). The search is case-insensitive
and will match any part of the game name.

.PARAMETER LaunchGame
Launch the game after finding it. When used with WaitForExit, the script will
also wait for the game to close.

.PARAMETER WaitForExit
Wait for the game to exit after launching. This is useful for automation scenarios
where you need to perform actions after a game closes.

.PARAMETER ShowDetails
Show detailed information about the game, including installation location,
launch options, and registry entries.

.PARAMETER ListGames
List all installed Steam games with their AppIDs.

.PARAMETER ListSteamAccountIds
List all Steam account IDs/usernames that have logged in on this computer,
highlighting the default account.

.PARAMETER Pass
Pass-through mode. Directly find and launch a game with minimal output. When combined with
GameName or AppId, it will automatically attempt to launch the game without
requiring additional confirmation. Returns immediately without waiting for the game to exit.

.PARAMETER Online
Run the script in online mode. This enables online checks or API calls.

.PARAMETER CopyLaunchCommand
Copies a launch command for a Steam game to the clipboard for use with Apollo/Sunshine.

.PARAMETER SteamAccountId
Specifies a Steam Account ID or nickname to use when launching the game. This is useful when 
you have multiple Steam accounts and want to launch a game with a specific account.

.PARAMETER LaunchParameters
Additional parameters to pass to the game when launching it. This is passed as launch options 
to the Steam client, which then passes them to the game.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -ListGames

Lists all installed Steam games with their AppIDs.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -AppId 1465360

Find and show basic information about SnowRunner (AppID: 1465360).

.EXAMPLE
PS> .\SteamLibrarian.ps1 -GameName "Snow" -LaunchGame

Find a game with "Snow" in the name, show info, and launch it.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -AppId 1465360 -LaunchGame -WaitForExit

Launch SnowRunner and wait for it to exit.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -GameName "Runner" -ShowDetails

Find a game with "Runner" in the name and display detailed information.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -Pass -GameName "Expeditions"

Quickly finds and launches the game "Expeditions: A MudRunner Game" without additional prompts.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -Pass -AppId 2477340

Directly launches the game with AppId 2477340 in pass-through mode.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -CopyLaunchCommand -AppId 1465360

Copies the launch command for SnowRunner (AppID: 1465360) to the clipboard.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -GameName "Expeditions" -LaunchGame -SteamAccountId "YourSteamUsername"

Finds and launches the "Expeditions" game with a specific Steam account.

.EXAMPLE
PS> .\SteamLibrarian.ps1 -AppId 1465360 -LaunchGame -LaunchParameters "-windowed -width 1920 -height 1080"

Launches SnowRunner with custom launch parameters for window size.

.INPUTS
None. You cannot pipe objects to SteamLibrarian.ps1.

.OUTPUTS
System.Management.Automation.PSCustomObject. Returns a custom object with game information
when running with AppId or GameName parameters.

.NOTES
File Name      : SteamLibrarian.ps1
Version        : 1.5
Creation Date  : May 7, 2025
Last Update    : May 23, 2025
Requires       : PowerShell 5.0 or later
                 Steam Client installed
OS             : Windows
Requirements   : Administrator privileges not required

This script uses a combination of registry checks, manifest file parsing, and process monitoring
to provide a comprehensive Steam game management experience.

.LINK
https://steamcommunity.com/sharedfiles/filedetails/?id=873543244

.LINK
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help
#>

#region Script Parameters
[CmdletBinding(DefaultParameterSetName="List")]
param (
    [Parameter(ParameterSetName="ByAppId", Mandatory=$true, Position=0,
        HelpMessage="Enter the Steam AppID for the game")]
    [int]$AppId,
    
    [Parameter(ParameterSetName="ByName", Mandatory=$true,
        HelpMessage="Enter the name or partial name of the game")]
    [string]$GameName,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [switch]$LaunchGame,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [switch]$WaitForExit,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [switch]$ShowDetails,
    
    [Parameter(ParameterSetName="List")]
    [switch]$ListGames,
    
    [Parameter(ParameterSetName="List")]
    [switch]$ListSteamAccountIds,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [switch]$Pass,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [Parameter(ParameterSetName="List")]
    [switch]$Online,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [switch]$CopyLaunchCommand,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [string]$SteamAccountId,
    
    [Parameter(ParameterSetName="ByAppId")]
    [Parameter(ParameterSetName="ByName")]
    [string]$LaunchParameters
)
#endregion Script Parameters

#region Logging Functions
function Write-LogMessage {
    <#
    .SYNOPSIS
    Writes a formatted log message to the console.

    .DESCRIPTION
    This function writes a log message with timestamp and type formatting.
    Different message types are displayed with different colors.

    .PARAMETER Message
    The log message to display.

    .PARAMETER Type
    The type of message (Info, Warning, Error, Success).
    Different types are displayed in different colors.

    .EXAMPLE
    Write-LogMessage "Steam game launched successfully" -Type "Success"

    .EXAMPLE
    Write-LogMessage "Could not find Steam installation" -Type "Error"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,
        
        [Parameter(Position=1)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Type) {
        "Info"    { "White" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Success" { "Green" }
    }
    
    Write-Host "[$timestamp] " -NoNewline
    Write-Host "[$Type] " -ForegroundColor $color -NoNewline
    Write-Host $Message
}
#endregion Logging Functions

#region Apollo Integration
function Copy-LaunchCommand {
    <#
    .SYNOPSIS
    Copies a launch command for a Steam game to the clipboard for use with Apollo/Sunshine.

    .DESCRIPTION
    Generates and copies to clipboard a PowerShell command that launches a specific Steam game 
    using the SteamLibrarian script. This is designed for integration with Apollo/Sunshine
    streaming server configurations.

    .PARAMETER AppId
    The Steam AppID of the game.

    .PARAMETER GameName
    The name of the game (for display purposes).

    .PARAMETER ScriptPath
    The full path to the SteamLibrarian script.
    
    .PARAMETER SteamAccountId
    Optional Steam Account ID or nickname to use for launching the game.
    
    .PARAMETER LaunchParameters
    Optional parameters to pass to the game when launching it.

    .EXAMPLE
    Copy-LaunchCommand -AppId 1465360 -GameName "SnowRunner" -ScriptPath "C:\Scripts\SteamLibrarian.ps1"
    
    .EXAMPLE
    Copy-LaunchCommand -AppId 1465360 -GameName "SnowRunner" -ScriptPath "C:\Scripts\SteamLibrarian.ps1" -SteamAccountId "YourSteamUsername" -LaunchParameters "-windowed"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$AppId,
        
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath,
        
        [Parameter()]
        [string]$SteamAccountId = "",
        
        [Parameter()]
        [string]$LaunchParameters = ""
    )
    
    # Create the command with default parameters
    $command = "powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`" -AppId $AppId -LaunchGame -WaitForExit"
    
    # Add Steam account if specified
    if ($SteamAccountId) {
        $command += " -SteamAccountId `"$SteamAccountId`""
    }
    
    # Add launch parameters if specified
    if ($LaunchParameters) {
        $command += " -LaunchParameters `"$LaunchParameters`""
    }
    
    try {
        # Copy to clipboard
        Set-Clipboard -Value $command -ErrorAction Stop
        
        Write-LogMessage "Launch command for '$GameName' copied to clipboard!" -Type "Success"
        
        # Show Apollo integration information
        Write-Host "`n=== APOLLO/SUNSHINE INTEGRATION COMMAND ===" -ForegroundColor Green
        Write-Host "Command copied to clipboard:" -ForegroundColor Cyan
        Write-Host $command -ForegroundColor Yellow
        
        # Show Apollo configuration format
        Write-Host "`nFor Apollo/Sunshine configuration:" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Host "Application Name: " -NoNewline -ForegroundColor White
        Write-Host "$GameName" -ForegroundColor Yellow
        Write-Host "Command: " -NoNewline -ForegroundColor White
        Write-Host "$command" -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        
        # Add warning about game launchers
        Write-Host "`nIMPORTANT NOTES:" -ForegroundColor Red
        Write-Host "1. Games with external launchers (Epic, Ubisoft Connect, etc.) may not work properly" -ForegroundColor Yellow
        Write-Host "2. Initial game setup should be done manually to avoid installer/dependency issues" -ForegroundColor Yellow
        Write-Host "3. Test the game launch manually before adding to Apollo/Sunshine" -ForegroundColor Yellow
        Write-Host "=======================================" -ForegroundColor Green
    }
    catch {
        Write-LogMessage "Failed to copy command to clipboard: $_" -Type "Error"
        Write-Host "`nCommand for Apollo/Sunshine integration:" -ForegroundColor Cyan
        Write-Host $command -ForegroundColor Yellow
    }
}
#endregion Apollo Integration

#region Steam Location Functions
function Get-SteamPath {
    <#
    .SYNOPSIS
    Gets the installation path of Steam on the local system.

    .DESCRIPTION
    Attempts to find the Steam installation path through several methods:
    1. Checking the registry
    2. Looking in common installation directories

    .OUTPUTS
    System.String. Returns the path to Steam or $null if not found.

    .EXAMPLE
    $steamPath = Get-SteamPath
    if ($steamPath) {
        Write-Host "Steam found at: $steamPath"
    }
    #>
    [CmdletBinding()]
    param()
    
    $possiblePaths = @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Steam"
    )
    
    # Check registry for Steam path
    try {
        $registryPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
        if ($registryPath -and (Test-Path $registryPath.SteamPath)) {
            return $registryPath.SteamPath
        }
    }
    catch {
        Write-LogMessage "Could not find Steam path in registry" -Type "Warning"
    }
    
    # Check common paths
    foreach ($path in $possiblePaths) {
        if (Test-Path "$path\steam.exe") {
            return $path
        }
    }
    
    return $null
}

function Get-SteamLibraryFolders {
    <#
    .SYNOPSIS
    Gets all Steam library folders where games can be installed.

    .DESCRIPTION
    Reads the Steam libraryfolders.vdf file to find all configured Steam libraries.
    Always includes the default Steam library.

    .PARAMETER SteamPath
    The path to the Steam installation directory.

    .OUTPUTS
    System.Array. Returns an array of Steam library paths.

    .EXAMPLE
    $libraries = Get-SteamLibraryFolders -SteamPath "C:\Program Files (x86)\Steam"
    foreach ($lib in $libraries) {
        Write-Host "Library: $lib"
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SteamPath
    )
    
    $libraryFolders = @()
    $libraryFoldersFile = "$SteamPath\steamapps\libraryfolders.vdf"
    
    if (Test-Path $libraryFoldersFile) {
        $content = Get-Content $libraryFoldersFile -Raw
        
        # Add the default Steam library
        $libraryFolders += "$SteamPath\steamapps"
        
        # Parse the VDF file to extract library paths
        $regex = '"path"\s+"([^"]+)"'
        $matches = [regex]::Matches($content, $regex)
        
        foreach ($match in $matches) {
            $path = $match.Groups[1].Value.Replace("\\", "\")
            if (Test-Path "$path\steamapps") {
                $libraryFolders += "$path\steamapps"
            }
        }
    }
    else {
        # If no library folders file, just use the default Steam library
        $libraryFolders += "$SteamPath\steamapps"
    }
    
    return $libraryFolders
}
#endregion Steam Location Functions

#region Steam Account Management Functions
function Get-SteamAccountIds {
    <#
    .SYNOPSIS
    Gets all Steam account IDs/usernames that have logged in on this computer.

    .DESCRIPTION
    Reads the Steam loginusers.vdf file to find all Steam accounts that have logged in.
    Also identifies the currently active (default) account.

    .PARAMETER SteamPath
    The path to the Steam installation directory.

    .OUTPUTS
    System.Array. Returns an array of custom objects with Steam account information.

    .EXAMPLE
    $accounts = Get-SteamAccountIds -SteamPath "C:\Program Files (x86)\Steam"
    foreach ($account in $accounts) {
        Write-Host "Account: $($account.AccountName) - Last Login: $($account.LastLogin)"
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SteamPath = ""
    )
    
    if (-not $SteamPath) {
        $SteamPath = Get-SteamPath
    }
    
    if (-not $SteamPath) {
        Write-LogMessage "Steam installation not found" -Type "Error"
        return $null
    }
    
    $loginUsersFile = Join-Path -Path $SteamPath -ChildPath "config\loginusers.vdf"
    if (-not (Test-Path $loginUsersFile)) {
        Write-LogMessage "Steam loginusers.vdf file not found at $loginUsersFile" -Type "Error"
        return $null
    }
    
    $content = Get-Content $loginUsersFile -Raw
    $accounts = @()
    
    # Get the active account from registry
    $activeAccountId = $null
    try {
        $registryPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
        if ($registryPath -and $registryPath.AutoLoginUser) {
            $activeAccountId = $registryPath.AutoLoginUser
        }
    }
    catch {
        Write-LogMessage "Could not determine active Steam account from registry" -Type "Warning"
    }
    
    # Parse the loginusers.vdf file
    # Sample format:
    # "users"
    # {
    #   "12345678901234567"
    #   {
    #     "AccountName"    "username"
    #     "PersonaName"    "Display Name"
    #     "RememberPassword"    "1"
    #     "MostRecent"     "1"
    #     "Timestamp"      "1589784000"
    #   }
    # }
    
    if ($content -match '"users"\s*{(.*)}') {
        $usersSection = $matches[1]
        
        # Extract each user section
        $userPattern = '"(\d+)"\s*{([^}]+)}'
        $userMatches = [regex]::Matches($usersSection, $userPattern)
        
        foreach ($userMatch in $userMatches) {
            $steamId = $userMatch.Groups[1].Value
            $userProperties = $userMatch.Groups[2].Value
            
            # Extract account properties
            $accountName = if ($userProperties -match '"AccountName"\s*"([^"]+)"') { $matches[1] } else { "Unknown" }
            $personaName = if ($userProperties -match '"PersonaName"\s*"([^"]+)"') { $matches[1] } else { $accountName }
            $mostRecent = if ($userProperties -match '"MostRecent"\s*"(\d+)"') { [bool]::Parse($matches[1]) } else { $false }
            $timestamp = if ($userProperties -match '"Timestamp"\s*"(\d+)"') { 
                # Convert Unix timestamp to DateTime
                [DateTimeOffset]::FromUnixTimeSeconds([long]$matches[1]).DateTime
            } else { 
                [DateTime]::MinValue 
            }
            
            # Determine if this is the active account
            $isActive = ($accountName -eq $activeAccountId) -or ($mostRecent -and -not $activeAccountId)
            
            $account = [PSCustomObject]@{
                SteamId = $steamId
                AccountName = $accountName
                PersonaName = $personaName
                IsActive = $isActive
                LastLogin = $timestamp
            }
            
            $accounts += $account
        }
    }
    
    # Sort by LastLogin (most recent first)
    return $accounts | Sort-Object -Property LastLogin -Descending
}

function Show-SteamAccountIds {
    <#
    .SYNOPSIS
    Displays all Steam account IDs/usernames that have logged in on this computer.

    .DESCRIPTION
    Lists all Steam accounts that have logged in, highlighting the currently active account.

    .PARAMETER SteamPath
    The path to the Steam installation directory.

    .EXAMPLE
    Show-SteamAccountIds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SteamPath = ""
    )
    
    $accounts = Get-SteamAccountIds -SteamPath $SteamPath
    
    if (-not $accounts -or $accounts.Count -eq 0) {
        Write-LogMessage "No Steam accounts found" -Type "Warning"
        return
    }
    
    Write-Host "`n-- Steam Accounts --" -ForegroundColor Cyan
    Write-Host "Default account is marked with *`n"
    
    foreach ($account in $accounts) {
        if ($account.IsActive) {
            Write-Host "* " -ForegroundColor Green -NoNewline
        } else {
            Write-Host "  " -NoNewline
        }
        
        Write-Host "$($account.AccountName)" -ForegroundColor White -NoNewline
        Write-Host " (Display Name: " -NoNewline
        Write-Host "$($account.PersonaName)" -ForegroundColor Yellow -NoNewline
        Write-Host ")"
        Write-Host "    Last login: $($account.LastLogin)" -ForegroundColor Gray
    }
    
    Write-Host "`nTo launch a game with a specific account, use:" -NoNewline
    Write-Host " -SteamAccountId <AccountName>" -ForegroundColor Yellow
    Write-Host "Example: .\SteamLibrarian.ps1 -GameName `"Portal`" -LaunchGame -SteamAccountId `"$($accounts[0].AccountName)`"`n"
}
#endregion Steam Account Management Functions

#region Game Management Functions
function Get-InstalledSteamGames {
    <#
    .SYNOPSIS
    Gets all installed Steam games from all Steam libraries.

    .DESCRIPTION
    Scans all Steam libraries for installed games by reading app manifest files.
    Returns a collection of game objects with basic information.

    .PARAMETER SteamPath
    The path to the Steam installation directory.

    .OUTPUTS
    System.Array. Returns an array of custom objects with game information.

    .EXAMPLE
    $games = Get-InstalledSteamGames -SteamPath "C:\Program Files (x86)\Steam"
    $games | Format-Table -Property AppId, Name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SteamPath
    )
    
    $games = @()
    $libraries = Get-SteamLibraryFolders -SteamPath $SteamPath
    $processedAppIds = @{}
    
    foreach ($library in $libraries) {
        $manifestFiles = Get-ChildItem -Path $library -Filter "appmanifest_*.acf" -ErrorAction SilentlyContinue
        
        foreach ($manifestFile in $manifestFiles) {
            try {
                $content = Get-Content $manifestFile.FullName -Raw
                
                # Extract key information from the manifest
                $appIdMatch = [regex]::Match($content, '"appid"\s+"(\d+)"')
                $nameMatch = [regex]::Match($content, '"name"\s+"([^"]+)"')
                $installDirMatch = [regex]::Match($content, '"installdir"\s+"([^"]+)"')
                
                if ($appIdMatch.Success -and $nameMatch.Success) {
                    $appId = $appIdMatch.Groups[1].Value
                    $name = $nameMatch.Groups[1].Value
                    $installDir = if ($installDirMatch.Success) { $installDirMatch.Groups[1].Value } else { "" }
                    
                    # Only add the game if we haven't seen this AppID before
                    if (-not $processedAppIds.ContainsKey($appId)) {
                        $processedAppIds[$appId] = $true
                        
                        $games += [PSCustomObject]@{
                            AppId = [int]$appId
                            Name = $name
                            InstallDir = $installDir
                            ManifestPath = $manifestFile.FullName
                            LibraryPath = $library
                        }
                    }
                }
            }
            catch {
                Write-LogMessage "Error parsing manifest file $($manifestFile.FullName): $_" -Type "Error"
            }
        }
    }
    
    return $games
}

function Get-SteamAppInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$AppId,
        
        [Parameter(Mandatory=$true)]
        [string]$SteamPath
    )
    
    # Try to get info from app manifest first
    $games = Get-InstalledSteamGames -SteamPath $SteamPath
    $game = $games | Where-Object { $_.AppId -eq $AppId } | Select-Object -First 1
    
    if (-not $game) {
        # If not found in manifests, try to get info via Steam console
        try {
            # Open Steam console and get app info
            Write-LogMessage "Game not found in local manifests. Trying Steam console..." -Type "Info"
            
            # Launch Steam console
            Start-Process "steam://nav/console"
            Start-Sleep -Seconds 2
            
            # We can't directly interact with Steam console, so inform the user
            Write-LogMessage "Please enter 'app_info_print $AppId' in the Steam console and copy the output" -Type "Warning"
            Write-LogMessage "This script cannot directly access Steam console output" -Type "Warning"
            return $null
        }
        catch {
            Write-LogMessage "Could not get app info from Steam console: $_" -Type "Error"
            return $null
        }
    }
    
    # Get more detailed info from the manifest file
    try {
        $manifestContent = Get-Content $game.ManifestPath -Raw
        
        # Parse the manifest to extract key information
        # FIX: Change path construction to use steamapps/common instead of just common
        $installPath = Join-Path -Path (Split-Path -Path $game.LibraryPath -Parent) -ChildPath "common\$($game.InstallDir)"
        
        # Ensure the path includes 'steamapps'
        if ($installPath -notmatch '\\steamapps\\common\\') {
            $libraryRoot = Split-Path -Path $game.LibraryPath -Parent
            $installPath = Join-Path -Path $libraryRoot -ChildPath "common\$($game.InstallDir)"
            
            # If the path still doesn't look right, explicitly construct it
            if (-not (Test-Path $installPath)) {
                $steamAppsCommon = Join-Path -Path $SteamPath -ChildPath "steamapps\common"
                $installPath = Join-Path -Path $steamAppsCommon -ChildPath $game.InstallDir
            }
        }
        
        # Extract executable info if available
        $exePathMatch = [regex]::Match($manifestContent, '"executable"\s+"([^"]+)"')
        $exePath = if ($exePathMatch.Success) { $exePathMatch.Groups[1].Value } else { "" }
        
        # Create a more detailed game info object
        $gameInfo = [PSCustomObject]@{
            AppId = $game.AppId
            Name = $game.Name
            InstallDir = $game.InstallDir
            InstallPath = $installPath
            Executable = $exePath
            ManifestPath = $game.ManifestPath
            LaunchOptions = @()
        }
        
        # Try to extract launch options if they exist
        $launchOptionsMatch = [regex]::Matches($manifestContent, '"(\d+)"\s+{[^}]*"executable"\s+"([^"]+)"[^}]*}')
        if ($launchOptionsMatch.Count -gt 0) {
            foreach ($match in $launchOptionsMatch) {
                $index = $match.Groups[1].Value
                $exe = $match.Groups[2].Value
                
                # Try to get working directory
                $workingDirMatch = [regex]::Match($match.Value, '"workingdir"\s+"([^"]+)"')
                $workingDir = if ($workingDirMatch.Success) { $workingDirMatch.Groups[1].Value } else { "" }
                
                $gameInfo.LaunchOptions += [PSCustomObject]@{
                    Index = $index
                    Executable = $exe
                    WorkingDirectory = $workingDir
                }
            }
        }
        
        return $gameInfo
    }
    catch {
        Write-LogMessage "Error parsing app info: $_" -Type "Error"
        return $null
    }
}

function Start-SteamGame {
    <#
    .SYNOPSIS
    Launches a Steam game using the Steam protocol.

    .DESCRIPTION
    Uses the steam:// protocol to launch a game with the specified AppID.
    Optional launch options and Steam account can be provided.

    .PARAMETER AppId
    The Steam AppID of the game to launch.

    .PARAMETER LaunchOptions
    Optional launch options to pass to the game.

    .PARAMETER SteamAccountId
    Optional Steam Account ID or nickname to use for launching the game.

    .OUTPUTS
    System.Boolean. Returns $true if the game launch was attempted, $false on error.

    .EXAMPLE
    Start-SteamGame -AppId 440 -LaunchOptions "-windowed -noborder"

    .EXAMPLE
    Start-SteamGame -AppId 440 -SteamAccountId "YourSteamUsername"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$AppId,
        
        [Parameter()]
        [string]$LaunchOptions = "",
        
        [Parameter()]
        [string]$SteamAccountId = ""
    )
    
    Write-LogMessage "Launching Steam game with AppID: $AppId" -Type "Info"
    
    try {
        # Use Steam protocol to launch the game
        $steamUrl = "steam://rungameid/$AppId"
        
        # Add launch options if provided
        if ($LaunchOptions) {
            $steamUrl += "//$LaunchOptions"
        }
        
        # Add Steam account if provided
        if ($SteamAccountId) {
            Write-LogMessage "Using Steam account: $SteamAccountId" -Type "Info"
            
            # Check if Steam is running
            $steamProcess = Get-Process -Name steam -ErrorAction SilentlyContinue
            
            if ($steamProcess) {
                # Steam is running, we need to restart it with the specified account
                Write-LogMessage "Steam is already running. Restarting with account $SteamAccountId..." -Type "Info"
                
                # Close Steam
                $steamProcess | ForEach-Object { $_.CloseMainWindow() | Out-Null }
                Start-Sleep -Seconds 2
                
                # Kill any remaining Steam processes
                Get-Process -Name steam* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }
            
            # Start Steam with the specified account
            $steamPath = Get-SteamPath
            if ($steamPath) {
                $steamExePath = Join-Path -Path $steamPath -ChildPath "steam.exe"
                if (Test-Path $steamExePath) {
                    # Start Steam with the specified account
                    Start-Process -FilePath $steamExePath -ArgumentList "-login $SteamAccountId"
                    Write-LogMessage "Waiting for Steam to start with account $SteamAccountId..." -Type "Info"
                    Start-Sleep -Seconds 5
                }
            }
        } else {
            # Using default Steam account
            Write-LogMessage "Using default Steam account" -Type "Info"
        }
        
        # Launch the game
        Start-Process $steamUrl
        return $true
    }
    catch {
        Write-LogMessage "Failed to launch game: $_" -Type "Error"
        return $false
    }
}

function Wait-SteamGameExit {
    <#
    .SYNOPSIS
    Waits for a Steam game to start and then exit.

    .DESCRIPTION
    This function monitors the system for a launched Steam game and waits until it exits.
    It uses multiple detection methods including:
    1. Checking Steam registry entries for running games
    2. Monitoring for executable files from the game's installation directory
    3. Detecting new processes with main windows (fallback method)
    
    The function prioritizes finding actual game executables rather than launchers or installers.

    .PARAMETER AppId
    The Steam AppID of the game to monitor.

    .PARAMETER GameInfo
    Game information object containing install path and other details.

    .PARAMETER MaxWaitSeconds
    Maximum time to wait for game to start in seconds.

    .PARAMETER PollIntervalSeconds
    How frequently to check if the game is still running, in seconds.

    .OUTPUTS
    System.Boolean. Returns $true if game exit was detected successfully, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$AppId,
        
        [Parameter()]
        [PSObject]$GameInfo = $null,
        
        [Parameter()]
        [int]$MaxWaitSeconds = 30,
        
        [Parameter()]
        [int]$PollIntervalSeconds = 5
    )
    
    Write-LogMessage "Waiting for game to start..." -Type "Info"
    
    # Method 1: Check Steam registry for running game
    $registryPath = "HKCU:\Software\Valve\Steam\Apps\$AppId"
    $gameRunningByRegistry = $false
    $gameRunningByProcess = $false
    $gameProcesses = @()
    $potentialGameExecutables = @()
    
    # Try to identify potential game executables from installation directory if available
    if ($GameInfo -and (Test-Path $GameInfo.InstallPath)) {
        Write-Verbose "Searching for potential game executables in $($GameInfo.InstallPath)"
        
        # Collect all executables in the game directory, prioritizing likely game binaries
        try {
            # Ignore common installer/utility executables
            $ignorePatterns = @(
                "*unins*.exe", "*setup*.exe", "*install*.exe", "*redist*",
                "*vcredist*.exe", "*directx*.exe", "*launcher*.exe", 
                "*crash*.exe", "*report*.exe", "*update*.exe"
            )
            
            # Search for executables with reasonable depth limitation
            $allExeFiles = Get-ChildItem -Path $GameInfo.InstallPath -Filter "*.exe" -Recurse -Depth 3 -ErrorAction SilentlyContinue
            
            # Filter and sort executables by size (larger files are more likely to be the main game)
            $potentialGameExecutables = $allExeFiles | 
                Where-Object {
                    $skipFile = $false
                    foreach ($pattern in $ignorePatterns) {
                        if ($_.Name -like $pattern) {
                            $skipFile = $true
                            break
                        }
                    }
                    -not $skipFile
                } | 
                Sort-Object -Property Length -Descending |
                Select-Object -First 5
            
            if ($potentialGameExecutables.Count -gt 0) {
                Write-Verbose "Found $($potentialGameExecutables.Count) potential game executables:"
                $potentialGameExecutables | ForEach-Object {
                    Write-Verbose "  - $($_.Name) (Size: $([Math]::Round($_.Length / 1MB, 2)) MB)"
                }
            } else {
                Write-Verbose "No potential game executables found in game directory."
            }
        }
        catch {
            Write-Verbose "Error searching for game executables: $_"
        }
    }
    
    # Get initial processes before game launch
    $initialProcesses = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | 
                        Select-Object Id, Name, MainWindowTitle, Path, StartTime, CPU, WorkingSet
    
    # Wait for game to start
    $timer = 0
    $gameStarted = $false
    
    while (-not $gameStarted -and $timer -lt $MaxWaitSeconds) {
        # Check method 1: Registry
        if (Test-Path $registryPath) {
            try {
                $appInfo = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
                if ($appInfo -and $appInfo.Running -eq 1) {
                    $gameStarted = $true
                    $gameRunningByRegistry = $true
                    Write-LogMessage "Game detected as running via Steam registry" -Type "Success"
                }
            }
            catch {
                # Registry might not be accessible
            }
        }
        
        # Check method 2: Known game executables from install directory
        if (-not $gameStarted -and $potentialGameExecutables.Count -gt 0) {
            $currentProcesses = Get-Process -ErrorAction SilentlyContinue
            
            foreach ($exeFile in $potentialGameExecutables) {
                $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exeFile.Name)
                $matchingProcess = $currentProcesses | Where-Object { $_.Name -eq $exeName }
                
                if ($matchingProcess) {
                    # Found a matching process from our known game executables
                    foreach ($process in $matchingProcess) {
                        try {
                            # Ensure this is a new process (wasn't in our initial list)
                            $isNewProcess = -not ($initialProcesses | Where-Object { $_.Id -eq $process.Id })
                            
                            if ($isNewProcess) {
                                $gameProcesses += $process
                                $gameStarted = $true
                                $gameRunningByProcess = $true
                                
                                # Display details about the detected game process
                                Write-Host "`n=== Detected Game Process (from known executables) ===" -ForegroundColor Green
                                Write-Host "Process Name: " -NoNewline -ForegroundColor Cyan; Write-Host $process.Name
                                Write-Host "Process ID:   " -NoNewline -ForegroundColor Cyan; Write-Host $process.Id
                                
                                try {
                                    if ($process.MainWindowTitle) {
                                        Write-Host "Window Title: " -NoNewline -ForegroundColor Cyan; Write-Host $process.MainWindowTitle
                                    }
                                } catch { }
                                
                                try {
                                    if ($process.Path) {
                                        Write-Host "Executable:   " -NoNewline -ForegroundColor Cyan; Write-Host $process.Path
                                    }
                                } catch { }
                                
                                try {
                                    if ($process.StartTime) {
                                        Write-Host "Start Time:   " -NoNewline -ForegroundColor Cyan; Write-Host $process.StartTime
                                    }
                                } catch { }
                                
                                try {
                                    $memoryInMB = [math]::Round($process.WorkingSet / 1MB, 2)
                                    Write-Host "Memory Usage: " -NoNewline -ForegroundColor Cyan; Write-Host "$memoryInMB MB"
                                } catch { }
                                
                                Write-Host "==========================`n" -ForegroundColor Green
                                
                                Write-LogMessage "Game process detected: $($process.Name) (PID: $($process.Id)) [From known game executable]" -Type "Success"
                                break
                            }
                        }
                        catch {
                            # Process may have ended already
                        }
                    }
                }
                
                if ($gameStarted) { break }
            }
        }
        
        # Check method 3: Process monitoring (fallback)
        if (-not $gameStarted) {
            $currentProcesses = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | 
                              Select-Object Id, Name, MainWindowTitle, Path, StartTime, CPU, WorkingSet
            
            $newProcesses = $currentProcesses | Where-Object { 
                $currId = $_.Id
                -not ($initialProcesses | Where-Object { $_.Id -eq $currId })
            }
            
            if ($newProcesses.Count -gt 0) {
                foreach ($process in $newProcesses) {
                    try {
                        # Skip the Steam process itself and other typical non-game processes
                        if ($process.Name -notlike "*steam*" -and 
                            $process.Name -notlike "*crash*" -and 
                            $process.Name -notlike "*report*" -and
                            $process.Name -notlike "*helper*" -and
                            $process.Name -notlike "*update*" -and
                            $process.MainWindowHandle -ne 0) {
                            
                            $gameProcesses += $process
                            $gameStarted = $true
                            $gameRunningByProcess = $true
                            
                            # Display details about the detected game process
                            Write-Host "`n=== Detected Game Process (by window handle) ===" -ForegroundColor Green
                            Write-Host "Process Name: " -NoNewline -ForegroundColor Cyan; Write-Host $process.Name
                            Write-Host "Process ID:   " -NoNewline -ForegroundColor Cyan; Write-Host $process.Id
                            
                            if ($process.MainWindowTitle) {
                                Write-Host "Window Title: " -NoNewline -ForegroundColor Cyan; Write-Host $process.MainWindowTitle
                            }
                            
                            if ($process.Path) {
                                Write-Host "Executable:   " -NoNewline -ForegroundColor Cyan; Write-Host $process.Path
                            }
                            
                            if ($process.StartTime) {
                                Write-Host "Start Time:   " -NoNewline -ForegroundColor Cyan; Write-Host $process.StartTime
                            }
                            
                            $memoryInMB = [math]::Round($process.WorkingSet / 1MB, 2)
                            Write-Host "Memory Usage: " -NoNewline -ForegroundColor Cyan; Write-Host "$memoryInMB MB"
                            Write-Host "==========================`n" -ForegroundColor Green
                            
                            Write-LogMessage "Game process detected: $($process.Name) (PID: $($process.Id)) [By window handle]" -Type "Success"
                        }
                    }
                    catch {
                        # Process may have ended already
                    }
                }
            }
        }
        
        if (-not $gameStarted) {
            Start-Sleep -Seconds 1
            $timer++
            
            # Show progress dots every few seconds
            if ($timer % 3 -eq 0) {
                Write-Host "." -NoNewline -ForegroundColor Yellow
            }
        }
    }
    
    if (-not $gameStarted) {
        Write-LogMessage "Could not detect game launch after $MaxWaitSeconds seconds" -Type "Warning"
        return $false
    }
    
    # Wait for game to exit
    Write-LogMessage "Game is running. Waiting for it to exit..." -Type "Info"
    
    $gameRunning = $true
    $startTime = Get-Date
    $lastStatusUpdate = $startTime
    
    while ($gameRunning) {
        $gameRunning = $false
        $currentTime = Get-Date
        
        # Check if any of our detected game processes are still running
        if ($gameRunningByProcess) {
            foreach ($process in $gameProcesses) {
                try {
                    $proc = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                    if ($proc) {
                        $gameRunning = $true
                        
                        # Update process stats every 30 seconds
                        $elapsedSeconds = ($currentTime - $lastStatusUpdate).TotalSeconds
                        if ($elapsedSeconds -ge 30) {
                            try {
                                $memoryInMB = [math]::Round($proc.WorkingSet / 1MB, 2)
                                $cpuTime = $proc.TotalProcessorTime.TotalSeconds
                                $runtime = $currentTime - $proc.StartTime
                                Write-LogMessage "Game running for $($runtime.Hours)h $($runtime.Minutes)m $($runtime.Seconds)s | CPU time: $([math]::Round($cpuTime,1))s | Memory: $memoryInMB MB" -Type "Info"
                                $lastStatusUpdate = $currentTime
                            }
                            catch {
                                # Ignore errors when getting process stats
                            }
                        }
                        break
                    }
                }
                catch {
                    # Process has ended
                }
            }
        }
        
        # Also check the registry as a backup
        if ($gameRunningByRegistry -and -not $gameRunning) {
            try {
                $appInfo = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
                if ($appInfo -and $appInfo.Running -eq 1) {
                    $gameRunning = $true
                }
            }
            catch {
                # Registry might not be accessible
            }
        }
        
        if ($gameRunning) {
            Start-Sleep -Seconds $PollIntervalSeconds
        }
    }
    
    # Show final process stats
    if ($gameProcesses.Count -gt 0) {
        try {
            Write-Host "`n=== Game Process Statistics ===" -ForegroundColor Green
            foreach ($process in $gameProcesses) {
                try {
                    $endTime = Get-Date
                    $runTime = $endTime - $process.StartTime
                    
                    Write-Host "Process Name: " -NoNewline -ForegroundColor Cyan; Write-Host $process.Name
                    Write-Host "Process ID:   " -NoNewline -ForegroundColor Cyan; Write-Host $process.Id
                    Write-Host "Runtime:      " -NoNewline -ForegroundColor Cyan
                    Write-Host "$($runTime.Hours)h $($runTime.Minutes)m $($runTime.Seconds)s"
                    
                    # Try to get final CPU and memory stats
                    try {
                        # CPU time in seconds
                        $cpuTimeInfo = Get-WmiObject Win32_Process -Filter "ProcessId = $($process.Id)" -ErrorAction SilentlyContinue
                        if ($cpuTimeInfo) {
                            $userTime = [math]::Round($cpuTimeInfo.UserModeTime / 10000000, 2)
                            $kernelTime = [math]::Round($cpuTimeInfo.KernelModeTime / 10000000, 2)
                            Write-Host "CPU Time:     " -NoNewline -ForegroundColor Cyan
                            Write-Host "User: ${userTime}s, Kernel: ${kernelTime}s, Total: $([math]::Round($userTime + $kernelTime, 2))s"
                        }
                    }
                    catch {
                        # Unable to get CPU time info
                    }
                    
                    Write-Host "==========================`n" -ForegroundColor Green
                }
                catch {
                    # Process information may not be available
                }
            }
        }
        catch {
            # Ignore errors when getting final stats
        }
    }
    
    Write-LogMessage "Game has exited" -Type "Success"
    return $true
}
#endregion Game Management Functions

#region Game Details Function
function Show-GameDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$GameInfo,
        
        [Parameter()]
        [switch]$Online
    )
    
    Write-Host "`n====== GAME DETAILS ======" -ForegroundColor Cyan
    Write-Host "AppID:        " -NoNewline -ForegroundColor Cyan; Write-Host $GameInfo.AppId
    Write-Host "Name:         " -NoNewline -ForegroundColor Cyan; Write-Host $GameInfo.Name
    Write-Host "Install Dir:  " -NoNewline -ForegroundColor Cyan; Write-Host $GameInfo.InstallDir
    Write-Host "Install Path: " -NoNewline -ForegroundColor Cyan; Write-Host "`"$($GameInfo.InstallPath)`""
    
    # Show primary executable information
    if ($GameInfo.Executable) {
        $executablePath = Join-Path -Path $GameInfo.InstallPath -ChildPath $GameInfo.Executable
        Write-Host "Executable:   " -NoNewline -ForegroundColor Cyan; Write-Host "`"$executablePath`""
        
        # Check if executable exists
        if (Test-Path $executablePath) {
            $fileInfo = Get-Item $executablePath
            Write-Host "File Size:    " -NoNewline -ForegroundColor Cyan
            Write-Host "$([Math]::Round($fileInfo.Length / 1MB, 2)) MB"
            Write-Host "Last Modified:" -NoNewline -ForegroundColor Cyan
            Write-Host " $($fileInfo.LastWriteTime)"
            
            # Try to get file version info
            try {
                $versionInfo = $fileInfo.VersionInfo
                if ($versionInfo.ProductVersion) {
                    Write-Host "Version:      " -NoNewline -ForegroundColor Cyan
                    Write-Host $versionInfo.ProductVersion
                }
            }
            catch {
                # Version info may not be available for all executables
            }
        } else {
            Write-Host "Executable not found at expected location" -ForegroundColor Yellow
        }
    } else {
        # Look for executable files in the game directory with increased search depth
        Write-Host "Executable:   " -NoNewline -ForegroundColor Cyan
        Write-Host "Not specified in manifest, searching for possible executables..." -ForegroundColor Yellow
        
        $exeFiles = @()
        
        try {
            # First try in standard game directory
            try {
                if (Test-Path $GameInfo.InstallPath) {
                    $exeFiles = Get-ChildItem -Path $GameInfo.InstallPath -Filter "*.exe" -Recurse -Depth 3 -ErrorAction SilentlyContinue | 
                        Where-Object { -not ($_.Name -like "*uninst*" -or $_.Name -like "*setup*") } | 
                        Sort-Object -Property Length -Descending | 
                        Select-Object -First 10
                }
            } catch {
                # If we get an error, try an alternative approach with quoted paths
                $quotedPath = "`"$($GameInfo.InstallPath)`""
                $exeSearchCmd = "Get-ChildItem -Path $quotedPath -Filter '*.exe' -Recurse -Depth 3 -ErrorAction SilentlyContinue | Where-Object { -not (`$_.Name -like '*uninst*' -or `$_.Name -like '*setup*') } | Sort-Object -Property Length -Descending | Select-Object -First 10"
                $exeFiles = Invoke-Expression $exeSearchCmd
            }
                
            if ($exeFiles.Count -gt 0) {
                Write-Host "  Possible game executables (showing largest files):" -ForegroundColor Yellow
                foreach ($exe in $exeFiles) {
                    try {
                        $relativePath = $exe.FullName.Substring($GameInfo.InstallPath.Length + 1)
                        $exeSize = [Math]::Round($exe.Length / 1MB, 2)
                        
                        # Only show executables larger than 1MB to filter out small utility/helper exes
                        if ($exeSize -ge 1) {
                            Write-Host "  - `"$relativePath`"" -ForegroundColor White
                            Write-Host "    Size: $exeSize MB" -ForegroundColor DarkGray
                        }
                    } catch {
                        # Skip this exe if there's an error calculating its path
                    }
                }
            } else {
                # Fallback to custom search with steamapps path
                $steamappsPath = Split-Path -Parent $GameInfo.ManifestPath
                $parentDirectory = Split-Path -Parent $steamappsPath
                $altPath = Join-Path -Path $parentDirectory -ChildPath "common\$($GameInfo.InstallDir)"
                
                Write-Host "  Looking in alternative path: `"$altPath`"" -ForegroundColor Yellow
                
                try {
                    if (Test-Path $altPath) {
                        # Look for exe files in the most common game folders
                        $commonFolders = @("bin", "binaries", "game", "data", "win64", "win32", "x64", "x86")
                        $foundExes = $false
                        
                        # First check root directory
                        $rootExes = Get-ChildItem -Path $altPath -Filter "*.exe" -File -ErrorAction SilentlyContinue |
                            Where-Object { -not ($_.Name -like "*uninst*" -or $_.Name -like "*setup*") } |
                            Sort-Object -Property Length -Descending |
                            Select-Object -First 3
                            
                        if ($rootExes.Count -gt 0) {
                            foreach ($exe in $rootExes) {
                                $exeSize = [Math]::Round($exe.Length / 1MB, 2)
                                if ($exeSize -ge 1) {
                                    if (-not $foundExes) {
                                        Write-Host "  Found executable files:" -ForegroundColor Green
                                        $foundExes = $true
                                    }
                                    Write-Host "  - `"$($exe.Name)`" -ForegroundColor White
                                    Write-Host "    Size: $exeSize MB" -ForegroundColor DarkGray
                                }
                            }
                        }
                        
                        # Then check common subdirectories
                        foreach ($folder in $commonFolders) {
                            $folderPath = Join-Path -Path $altPath -ChildPath $folder
                            if (Test-Path $folderPath) {
                                $folderExes = Get-ChildItem -Path $folderPath -Filter "*.exe" -Recurse -Depth 1 -ErrorAction SilentlyContinue |
                                    Where-Object { -not ($_.Name -like "*uninst*" -or $_.Name -like "*setup*") } |
                                    Sort-Object -Property Length -Descending |
                                    Select-Object -First 3
                                
                                if ($folderExes.Count -gt 0) {
                                    foreach ($exe in $folderExes) {
                                        $relativePath = $exe.FullName.Substring($altPath.Length + 1)
                                        $exeSize = [Math]::Round($exe.Length / 1MB, 2)
                                        if ($exeSize -ge 1) {
                                            if (-not $foundExes) {
                                                Write-Host "  Found executable files:" -ForegroundColor Green
                                                $foundExes = $true
                                            }
                                            Write-Host "  - `"$relativePath`"" -ForegroundColor White
                                            Write-Host "    Size: $exeSize MB" -ForegroundColor DarkGray
                                        }
                                    }
                                }
                            }
                        }
                        
                        if (-not $foundExes) {
                            # Last resort: look in any subdirectory
                            $allDirs = Get-ChildItem -Path $altPath -Directory -ErrorAction SilentlyContinue
                            $deepSearch = $false
                            
                            foreach ($dir in $allDirs) {
                                $dirExes = Get-ChildItem -Path $dir.FullName -Filter "*.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                                    Where-Object { -not ($_.Name -like "*uninst*" -or $_.Name -like "*setup*") } |
                                    Sort-Object -Property Length -Descending |
                                    Select-Object -First 2
                                
                                if ($dirExes.Count -gt 0) {
                                    foreach ($exe in $dirExes) {
                                        $relativePath = $exe.FullName.Substring($altPath.Length + 1)
                                        $exeSize = [Math]::Round($exe.Length / 1MB, 2)
                                        if ($exeSize -ge 1) {
                                            if (-not $foundExes) {
                                                Write-Host "  Found executable files:" -ForegroundColor Green
                                                $foundExes = $true
                                            }
                                            Write-Host "  - `"$relativePath`"" -ForegroundColor White
                                            Write-Host "    Size: $exeSize MB" -ForegroundColor DarkGray
                                        }
                                    }
                                }
                            }
                            
                            if (-not $foundExes) {
                                Write-Host "  No executable files found in game directories" -ForegroundColor Red
                            }
                        }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Write-Host "  Alternative path does not exist" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "  Error searching alternative paths: $_" -ForegroundColor Red
                }
                
                # Try to use Steam nav console for executables
                Write-Host "`n  Try using Steam nav console commands to get game details:" -ForegroundColor Yellow
                Write-Host "  1. Open Steam `> View `> Console" -ForegroundColor Yellow
                Write-Host "  2. Type: app_info_print $($GameInfo.AppId)" -ForegroundColor Yellow
                Write-Host "  3. Look for 'executable' field in the output" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  Error searching for executables: $_" -ForegroundColor Red
            
            # Try to use Steam nav console for executables
            Write-Host "`n  Try using Steam nav console commands to get game details:" -ForegroundColor Yellow
            Write-Host "  1. Open Steam `> View `> Console" -ForegroundColor Yellow
            Write-Host "  2. Type: app_info_print $($GameInfo.AppId)" -ForegroundColor Yellow
            Write-Host "  3. Look for 'executable' field in the output" -ForegroundColor Yellow
        }
    }
    
    # Look for DLLs in root folder (can help identify engine)
    try {
        $engineDlls = Get-ChildItem -Path $GameInfo.InstallPath -Filter "*.dll" -File -Recurse -Depth 1 -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match "^(Unity|Unreal|CryEngine|CRYENGINE|Godot|Source|Engine|GameEngine)" } |
            Select-Object -First 3
            
        if ($engineDlls.Count -gt 0) {
            Write-Host "`nGame Engine:  " -NoNewline -ForegroundColor Cyan
            $engineNames = $engineDlls | ForEach-Object {
                if ($_.Name -match "Unity") { "Unity" }
                elseif ($_.Name -match "Unreal") { "Unreal Engine" }
                elseif ($_.Name -match "CryEngine|CRYENGINE") { "CryEngine" }
                elseif ($_.Name -match "Godot") { "Godot" }
                elseif ($_.Name -match "Source") { "Source Engine" }
                else { "Unknown Engine" }
            } | Select-Object -Unique
            Write-Host ($engineNames -join ", ")
        }
    } catch {
        # Failed to detect engine, continue
    }
    
    # Display manifest information
    Write-Host "`nManifest Path:" -NoNewline -ForegroundColor Cyan
    Write-Host " `"$($GameInfo.ManifestPath)`""
    
    # Try to extract more info from the manifest file
    try {
        $manifestContent = Get-Content $GameInfo.ManifestPath -Raw -ErrorAction SilentlyContinue
        
        # Extract interesting fields from the manifest
        $extractManifestValue = {
            param($content, $fieldName)
            $match = [regex]::Match($content, '(?s)"' + $fieldName + '"\s+"([^"]*)"')
            if ($match.Success) { return $match.Groups[1].Value }
            return $null
        }
        
        $stateFlags = & $extractManifestValue $manifestContent "StateFlags"
        $installDir = & $extractManifestValue $manifestContent "installdir"
        $lastUpdated = & $extractManifestValue $manifestContent "LastUpdated"
        $sizeOnDisk = & $extractManifestValue $manifestContent "SizeOnDisk"
        
        Write-Host "`nAdditional Manifest Information:" -ForegroundColor Cyan
        
        if ($stateFlags) {
            Write-Host "  State Flags:  " -NoNewline -ForegroundColor Cyan
            Write-Host "$stateFlags (4 = Fully installed)"
        }
        
        if ($lastUpdated) {
            try {
                $updateDateTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$lastUpdated).LocalDateTime
                Write-Host "  Last Updated: " -NoNewline -ForegroundColor Cyan
                Write-Host $updateDateTime.ToString("yyyy-MM-dd HH:mm:ss")
            } catch {
                Write-Host "  Last Updated: " -NoNewline -ForegroundColor Cyan
                Write-Host $lastUpdated
            }
        }
        
        if ($sizeOnDisk) {
            try {
                $sizeInGB = [Math]::Round([long]$sizeOnDisk / 1GB, 2)
                Write-Host "  Manifest Size:" -NoNewline -ForegroundColor Cyan
                Write-Host " $sizeInGB GB"
            } catch {
                Write-Host "  Manifest Size:" -NoNewline -ForegroundColor Cyan
                Write-Host " $sizeOnDisk bytes"
            }
        }
    } catch {
        # Failed to extract additional manifest info, continue
    }
    
    if ($GameInfo.LaunchOptions.Count -gt 0) {
        Write-Host "`nLaunch Options:" -ForegroundColor Cyan
        foreach ($option in $GameInfo.LaunchOptions) {
            Write-Host "  [$($option.Index)] Executable: " -NoNewline -ForegroundColor Cyan
            Write-Host "`"$($option.Executable)`""
            if ($option.WorkingDirectory) {
                Write-Host "      Working Dir: " -NoNewline -ForegroundColor Cyan
                Write-Host "`"$($option.WorkingDirectory)`""
            }
        }
    }
    
    # Display additional game files
    try {
        Write-Host "`nGame Directory Contents:" -ForegroundColor Cyan
        
        if (Test-Path $GameInfo.InstallPath) {
            $topLevelItems = Get-ChildItem -Path $GameInfo.InstallPath -ErrorAction SilentlyContinue | 
                Sort-Object -Property LastWriteTime -Descending | 
                Select-Object -First 10
                
            if ($topLevelItems.Count -gt 0) {
                $totalSize = 0
                foreach ($item in $topLevelItems) {
                    if ($item.PSIsContainer) {
                        # It's a directory
                        $dirInfo = Get-ChildItem -Path $item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
                        $itemSize = $dirInfo.Sum
                        $itemType = "Directory"
                    } else {
                        # It's a file
                        $itemSize = $item.Length
                        $itemType = $item.Extension.TrimStart('.')
                    }
                    
                    $totalSize += $itemSize
                    $sizeInMB = [Math]::Round($itemSize / 1MB, 2)
                    Write-Host "  `"$($item.Name)`"" -NoNewline 
                    Write-Host " ($itemType, $($sizeInMB) MB)" -ForegroundColor DarkGray
                }
                
                if ($topLevelItems.Count -eq 10) {
                    Write-Host "  ...and more files/directories (showing 10 most recently modified)"
                }
                
                # Try to calculate total game size
                try {
                    $allFiles = Get-ChildItem -Path $GameInfo.InstallPath -Recurse -File -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
                    $totalGameSize = [Math]::Round($allFiles.Sum / 1GB, 2)
                    Write-Host "`nTotal Game Size: " -NoNewline -ForegroundColor Cyan
                    Write-Host "$totalGameSize GB" -ForegroundColor White
                }
                catch {
                    # Calculating total size might fail on large game directories
                }
            } else {
                # Try alternative path
                $steamappsPath = Split-Path -Parent $GameInfo.ManifestPath
                $parentDirectory = Split-Path -Parent $steamappsPath
                $altPath = Join-Path -Path $parentDirectory -ChildPath "common\$($GameInfo.InstallDir)"
                
                Write-Host "  No files found in primary game directory, checking: `"$altPath`"" -ForegroundColor Yellow
                
                if (Test-Path $altPath) {
                    $topLevelAltItems = Get-ChildItem -Path $altPath -ErrorAction SilentlyContinue | 
                        Sort-Object -Property LastWriteTime -Descending | 
                        Select-Object -First 10
                        
                    if ($topLevelAltItems.Count -gt 0) {
                        foreach ($item in $topLevelAltItems) {
                            if ($item.PSIsContainer) {
                                Write-Host "  `"$($item.Name)`" (Directory)" -ForegroundColor White
                            } else {
                                $sizeInMB = [Math]::Round($item.Length / 1MB, 2)
                                Write-Host "  `"$($item.Name)`" ($sizeInMB MB)" -ForegroundColor White
                            }
                        }
                    } else {
                        Write-Host "  No files found in alternative game directory" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  Could not find game directory" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  Game directory not found: `"$($GameInfo.InstallPath)`"" -ForegroundColor Red
            
            # Try alternative path
            $steamappsPath = Split-Path -Parent $GameInfo.ManifestPath
            $parentDirectory = Split-Path -Parent $steamappsPath
            $commonPath = Join-Path -Path $parentDirectory -ChildPath "common"
            
            if (Test-Path $commonPath) {
                # Look for directories matching game name
                $potentialGameDirs = Get-ChildItem -Path $commonPath -Directory -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -like "*$($GameInfo.InstallDir)*" }
                
                if ($potentialGameDirs.Count -gt 0) {
                    Write-Host "  Found potential game directories:" -ForegroundColor Yellow
                    foreach ($dir in $potentialGameDirs) {
                        Write-Host "    - `"$($dir.FullName)`"" -ForegroundColor White
                    }
                }
            }
        }
    }
    catch {
        Write-Host "  Could not access game directory: $_" -ForegroundColor Yellow
    }
    
    # Try to get online information about the game if not in offline mode
    if ($Online) {
        try {
            Write-Host "`nOnline Information:" -ForegroundColor Cyan
            Write-Host "  Fetching data from Steam API..." -ForegroundColor DarkGray
            
            # Use proper API handling based on Steam's behavior with app IDs vs package IDs
            try {
                # Create a WebClient with timeout
                Add-Type -AssemblyName System.Net.Http
                $httpClient = New-Object System.Net.Http.HttpClient
                $httpClient.Timeout = New-TimeSpan -Seconds 8
                
                # Add user agent to prevent blocking
                $httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                $httpClient.DefaultRequestHeaders.Add("Accept", "application/json")
                
                # First try the standard app details API
                $steamApiUrl = "https://store.steampowered.com/api/appdetails?appids=$($GameInfo.AppId)"
                $task = $httpClient.GetStringAsync($steamApiUrl)
                
                # Wait for task with a timeout
                $gameDataObtained = $false
                if ([System.Threading.Tasks.Task]::WaitAll(@($task), 5000)) {
                    $response = $task.Result
                    
                    if ($response) {
                        $gameData = $response | ConvertFrom-Json
                        
                        # Check if the API returned success
                        if ($gameData."$($GameInfo.AppId)".success -eq $true) {
                            $gameDataObtained = $true
                            $data = $gameData."$($GameInfo.AppId)".data
                            
                            # Show game details from the API response
                            Write-Host "  Name:         " -NoNewline -ForegroundColor Cyan
                            Write-Host $data.name
                            
                            Write-Host "  Release Date: " -NoNewline -ForegroundColor Cyan
                            Write-Host $data.release_date.date
                            
                            if ($data.developers) {
                                Write-Host "  Developers:   " -NoNewline -ForegroundColor Cyan
                                Write-Host ($data.developers -join ", ")
                            }
                            
                            if ($data.publishers) {
                                Write-Host "  Publishers:   " -NoNewline -ForegroundColor Cyan
                                Write-Host ($data.publishers -join ", ")
                            }
                            
                            if ($data.metacritic.score) {
                                Write-Host "  Metacritic:   " -NoNewline -ForegroundColor Cyan
                                Write-Host "$($data.metacritic.score)/100"
                            }
                            
                            if ($data.categories) {
                                Write-Host "  Categories:   " -NoNewline -ForegroundColor Cyan
                                $categories = $data.categories | ForEach-Object { $_.description } | Select-Object -First 5 -Unique
                                Write-Host ($categories -join ", ")
                            }
                            
                            if ($data.genres) {
                                Write-Host "  Genres:       " -NoNewline -ForegroundColor Cyan
                                $genres = $data.genres | ForEach-Object { $_.description } | Select-Object -First 5 -Unique
                                Write-Host ($genres -join ", ")
                            }
                            
                            # Check for package IDs if this is a GOTY or special edition
                            if ($data.packages -and $data.packages.Count -gt 0) {
                                Write-Host "  Package IDs:  " -NoNewline -ForegroundColor Cyan
                                Write-Host ($data.packages -join ", ")
                            }
                        }
                    }
                }
                
                # If first API call failed, try the IStoreService approach
                if (-not $gameDataObtained) {
                    Write-Host "  Main app details failed, checking for alternative IDs..." -ForegroundColor Yellow
                    
                    # For special editions (like GOTY editions), the appID might not have its own store page
                    # We need to check the base game ID instead
                    
                    # Try a different approach, looking up related package IDs
                    $steamStoreUrl = "https://store.steampowered.com/api/appdetails?appids=$($GameInfo.AppId)&filters=basic"
                    $basicTask = $httpClient.GetStringAsync($steamStoreUrl)
                    
                    if ([System.Threading.Tasks.Task]::WaitAll(@($basicTask), 5000)) {
                        $basicResponse = $basicTask.Result
                        if ($basicResponse) {
                            $basicData = $basicResponse | ConvertFrom-Json
                            
                            # Check if this app has related packages
                            if ($basicData."$($GameInfo.AppId)".success -eq $false) {
                                Write-Host "  This game version ($($GameInfo.AppId)) might be a special edition without its own store page" -ForegroundColor Yellow
                                
                                # Find potential base game
                                $potentialBaseNames = @()
                                if ($GameInfo.Name -match "(Game of the Year|GOTY|Complete|Special|Definitive|Enhanced|Collection|Bundle|Edition)") {
                                    $baseName = $GameInfo.Name -replace "(Game of the Year|GOTY|Complete|Special|Definitive|Enhanced|Collection|Bundle|Edition).*$", ""
                                    $baseName = $baseName.Trim(" -:")
                                    $potentialBaseNames += $baseName
                                }
                                
                                if ($potentialBaseNames.Count -gt 0) {
                                    # Try to find similar games in the catalog
                                    Write-Host "  Looking for related base game: '$($potentialBaseNames[0])'" -ForegroundColor Yellow
                                    
                                    # Search for the base game in installed games
                                    $games = Get-InstalledSteamGames -SteamPath $SteamPath
                                    $potentialBaseGames = $games | Where-Object { 
                                        foreach ($name in $potentialBaseNames) {
                                            if ($_.Name -like "*$name*" -and $_.AppId -ne $GameInfo.AppId) {
                                                return $true
                                            }
                                        }
                                        return $false
                                    }
                                    
                                    if ($potentialBaseGames.Count -gt 0) {
                                        $baseGameId = $potentialBaseGames[0].AppId
                                        Write-Host "  Found potential base game: $($potentialBaseGames[0].Name) (AppID: $baseGameId)" -ForegroundColor Green
                                        
                                        # Try getting info for the base game
                                        $baseGameApiUrl = "https://store.steampowered.com/api/appdetails?appids=$baseGameId"
                                        $baseGameTask = $httpClient.GetStringAsync($baseGameApiUrl)
                                        
                                        if ([System.Threading.Tasks.Task]::WaitAll(@($baseGameTask), 5000)) {
                                            $baseGameResponse = $baseGameTask.Result
                                            if ($baseGameResponse) {
                                                $baseGameData = $baseGameResponse | ConvertFrom-Json
                                                
                                                if ($baseGameData."$baseGameId".success -eq $true) {
                                                    $gameDataObtained = $true
                                                    $data = $baseGameData."$baseGameId".data
                                                    
                                                    Write-Host "  Using base game information from: $($data.name) (AppID: $baseGameId)" -ForegroundColor Green
                                                    
                                                    # Show base game details
                                                    Write-Host "  Release Date: " -NoNewline -ForegroundColor Cyan
                                                    Write-Host $data.release_date.date
                                                    
                                                    if ($data.developers) {
                                                        Write-Host "  Developers:   " -NoNewline -ForegroundColor Cyan
                                                        Write-Host ($data.developers -join ", ")
                                                    }
                                                    
                                                    if ($data.publishers) {
                                                        Write-Host "  Publishers:   " -NoNewline -ForegroundColor Cyan
                                                        Write-Host ($data.publishers -join ", ")
                                                    }
                                                    
                                                    if ($data.metacritic.score) {
                                                        Write-Host "  Metacritic:   " -NoNewline -ForegroundColor Cyan
                                                        Write-Host "$($data.metacritic.score)/100"
                                                    }
                                                    
                                                    if ($data.categories) {
                                                        Write-Host "  Categories:   " -NoNewline -ForegroundColor Cyan
                                                        $categories = $data.categories | ForEach-Object { $_.description } | Select-Object -First 5 -Unique
                                                        Write-Host ($categories -join ", ")
                                                    }
                                                    
                                                    if ($data.genres) {
                                                        Write-Host "  Genres:       " -NoNewline -ForegroundColor Cyan
                                                        $genres = $data.genres | ForEach-Object { $_.description } | Select-Object -First 5 -Unique
                                                        Write-Host ($genres -join ", ")
                                                    }
                                                    
                                                    # Check for package IDs that might relate to this edition
                                                    if ($data.packages -and $data.packages.Count -gt 0) {
                                                        $packagesList = $data.packages -join ", "
                                                        Write-Host "  Package IDs:  " -NoNewline -ForegroundColor Cyan
                                                        Write-Host $packagesList
                                                        
                                                        # Explain the situation to the user
                                                        Write-Host "  Note: The original AppID $($GameInfo.AppId) may refer to a special edition" -ForegroundColor Yellow
                                                        Write-Host "        Check the base game and packages for more information" -ForegroundColor Yellow
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                # If we still don't have data, check if this might be a package ID issue
                # (As described in the Steam API discussions you shared)
                if (-not $gameDataObtained) {
                    Write-Host "  Standard API calls failed, trying alternative methods..." -ForegroundColor Yellow
                    Write-Host "  Note: Some special editions may use package IDs instead of app IDs" -ForegroundColor Yellow
                    Write-Host "        Try using SteamDB for more accurate information" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "  Failed to fetch online information: $_" -ForegroundColor Yellow
                
            } 
            finally {
                # Dispose of the HttpClient
                if ($httpClient) {
                    $httpClient.Dispose()
                }
            }
            
            # Always show all available links regardless of API success
            Write-Host "`n  Store Page:    " -NoNewline; Write-Host "https://store.steampowered.com/app/$($GameInfo.AppId)/" -ForegroundColor Blue
            Write-Host "  SteamDB:       " -NoNewline; Write-Host "https://steamdb.info/app/$($GameInfo.AppId)/" -ForegroundColor Blue
            Write-Host "  ProtonDB:      " -NoNewline; Write-Host "https://www.protondb.com/app/$($GameInfo.AppId)" -ForegroundColor Blue
            
            # Add hints about IStoreService API
            Write-Host "`n  API Note: For more complete app info, use IStoreService/GetAppList:" -ForegroundColor DarkGray
            Write-Host "           https://steamapi.xpaw.me/#IStoreService/GetAppList" -ForegroundColor DarkGray
        } 
        catch {
            Write-Host "`n  Failed to access online Steam information: $_" -ForegroundColor Yellow
            
            # Still show links
            Write-Host "  Store Page:    " -NoNewline; Write-Host "https://store.steampowered.com/app/$($GameInfo.AppId)/" -ForegroundColor Blue
            Write-Host "  SteamDB:       " -NoNewline; Write-Host "https://steamdb.info/app/$($GameInfo.AppId)/" -ForegroundColor Blue
            Write-Host "  ProtonDB:      " -NoNewline; Write-Host "https://www.protondb.com/app/$($GameInfo.AppId)" -ForegroundColor Blue
        }
    } else {
        # In offline mode, just show links
        Write-Host "`nOnline Resources (not fetched in offline mode):" -ForegroundColor Cyan
        Write-Host "  Store Page:    " -NoNewline; Write-Host "https://store.steampowered.com/app/$($GameInfo.AppId)/" -ForegroundColor Blue
        Write-Host "  SteamDB:       " -NoNewline; Write-Host "https://steamdb.info/app/$($GameInfo.AppId)/" -ForegroundColor Blue
        Write-Host "  ProtonDB:      " -NoNewline; Write-Host "https://www.protondb.com/app/$($GameInfo.AppId)" -ForegroundColor Blue
    }
    
    # Steam commands
    Write-Host "`nSteam Commands:" -ForegroundColor Cyan
    Write-Host "  Run Game:         " -NoNewline; Write-Host "steam://run/$($GameInfo.AppId)" -ForegroundColor Yellow
    Write-Host "  Game Store Page:  " -NoNewline; Write-Host "steam://store/$($GameInfo.AppId)" -ForegroundColor Yellow
    Write-Host "  Game Hub:         " -NoNewline; Write-Host "steam://url/GameHub/$($GameInfo.AppId)" -ForegroundColor Yellow
    Write-Host "  Steam Console:    " -NoNewline; Write-Host "steam://nav/console" -ForegroundColor Yellow
    Write-Host "    (Type 'app_info_print $($GameInfo.AppId)' in the console for detailed info)" -ForegroundColor DarkGray
    
    Write-Host "=========================" -ForegroundColor Cyan
}
#endregion Game Details Function

#region Main Function
function LaunchSteamGame {
    <#
    .SYNOPSIS
    Main function that processes command line parameters and executes the script logic.

    .DESCRIPTION
    Orchestrates the script's functionality based on provided parameters.
    This includes listing games, finding game information, launching games,
    and displaying detailed information.

    .PARAMETER AppId
    The Steam AppID of the game to manage.

    .PARAMETER GameName
    Search for a game by name (partial name is supported).

    .PARAMETER LaunchGame
    Launch the game after finding it.

    .PARAMETER WaitForExit
    Wait for the game to exit after launching.

    .PARAMETER ShowDetails
    Show detailed information about the game.

    .PARAMETER ListGames
    List all installed Steam games with their AppIDs.
    
    .PARAMETER ListSteamAccountIds
    List all Steam account IDs/usernames that have logged in on this computer,
    highlighting the default account.

    .PARAMETER Pass
    Pass-through mode. Directly find and launch a game with minimal output.

    .PARAMETER Online
    Run the script in online mode. This enables online checks or API calls.

    .PARAMETER CopyLaunchCommand
    Copies a launch command for a Steam game to the clipboard for use with Apollo/Sunshine.
    
    .PARAMETER SteamAccountId
    Specifies a Steam Account ID or nickname to use when launching the game.
    
    .PARAMETER LaunchParameters
    Additional parameters to pass to the game when launching it.

    .EXAMPLE
    LaunchSteamGame -ListGames
    LaunchSteamGame -AppId 440 -LaunchGame -WaitForExit
    LaunchSteamGame -GameName "Portal" -LaunchGame -SteamAccountId "YourSteamUsername"
    LaunchSteamGame -AppId 440 -LaunchGame -LaunchParameters "-windowed -noborder"
    #>
    [CmdletBinding(DefaultParameterSetName="List")]
    param (
        [Parameter(ParameterSetName="ByAppId", Mandatory=$true, Position=0)]
        [int]$AppId,
        
        [Parameter(ParameterSetName="ByName", Mandatory=$true)]
        [string]$GameName,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [switch]$LaunchGame,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [switch]$WaitForExit,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [switch]$ShowDetails,
        
        [Parameter(ParameterSetName="List")]
        [switch]$ListGames,
        
        [Parameter(ParameterSetName="List")]
        [switch]$ListSteamAccountIds,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [switch]$Pass,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [Parameter(ParameterSetName="List")]
        [switch]$Online,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [switch]$CopyLaunchCommand,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [string]$SteamAccountId,
        
        [Parameter(ParameterSetName="ByAppId")]
        [Parameter(ParameterSetName="ByName")]
        [string]$LaunchParameters
    )

    # Get Steam installation path
    $steamPath = Get-SteamPath
    if (-not $steamPath) {
        Write-LogMessage "Steam installation not found. Please make sure Steam is installed." -Type "Error"
        return 1
    }

    # Only show the Steam path if we're not in pass-through mode
    if (-not $Pass) {
        Write-LogMessage "Found Steam at: $steamPath" -Type "Info"
    }

    # Get list of installed Steam games
    $installedGames = Get-InstalledSteamGames -SteamPath $steamPath

    # Handle ListSteamAccountIds parameter
    if ($ListSteamAccountIds) {
        # Display list of Steam accounts
        Show-SteamAccountIds -SteamPath $steamPath
        return 0
    }
    
    if ($ListGames) {
        # Display list of installed games
        Write-Host "`n====== INSTALLED STEAM GAMES ======" -ForegroundColor Cyan
        $installedGames | Sort-Object Name | Format-Table -Property AppId, Name -AutoSize
        return 0
    }

    # If no parameters specified, show both accounts and games
    if (-not $PSBoundParameters.Count) {
        # Show Steam accounts
        Show-SteamAccountIds -SteamPath $steamPath
        
        # Show installed games
        Write-Host "`n====== INSTALLED STEAM GAMES ======" -ForegroundColor Cyan
        $installedGames | Sort-Object Name | Format-Table -Property AppId, Name -AutoSize
        
        # Show basic usage hint
        Write-Host "`nFor detailed help, use: " -NoNewline
        Write-Host "Get-Help $($MyInvocation.MyCommand.Name) -Detailed" -ForegroundColor Yellow
        return 0
    }

    # Find the specific game
    $gameInfo = $null

    if ($AppId) {
        # Find game by AppId
        if (-not $Pass) {
            Write-LogMessage "Looking for game with AppID: $AppId" -Type "Info"
        }
        $gameInfo = Get-SteamAppInfo -AppId $AppId -SteamPath $steamPath
        
        if (-not $gameInfo) {
            Write-LogMessage "Game with AppID $AppId not found or could not retrieve information" -Type "Error"
            return 1
        }
    }
    elseif ($GameName) {
        if (-not $Pass) {
            Write-LogMessage "Looking for games matching name: '$GameName'" -Type "Info"
        }
        
        # Better matching logic to prevent false multiple matches
        $exactMatch = $installedGames | Where-Object { $_.Name -eq $GameName }
        if ($exactMatch.Count -eq 1) {
            $matchingGames = $exactMatch
        } else {
            $caseInsensitiveExact = $installedGames | Where-Object { $_.Name -ieq $GameName }
            if ($caseInsensitiveExact.Count -ge 1) {
                $matchingGames = $caseInsensitiveExact
            } else {
                $matchingGames = $installedGames | Where-Object { $_.Name -like "*$GameName*" }
            }
        }
        
        # Remove duplicate matches that might occur due to case differences
        $uniqueMatches = @{}
        $uniqueMatchingGames = @()
        
        foreach ($game in $matchingGames) {
            if (-not $uniqueMatches.ContainsKey($game.AppId)) {
                $uniqueMatches[$game.AppId] = $true
                $uniqueMatchingGames += $game
            }
        }
        $matchingGames = $uniqueMatchingGames
        
        if ($matchingGames.Count -eq 0) {
            Write-LogMessage "No games found matching name: '$GameName'" -Type "Error"
            return 1
        }
        elseif ($matchingGames.Count -eq 1) {
            $gameInfo = Get-SteamAppInfo -AppId $matchingGames[0].AppId -SteamPath $steamPath
        }
        else {
            # Multiple games found
            # Skip interactive selection in pass-through mode and use first match
            if ($Pass) {
                $gameInfo = Get-SteamAppInfo -AppId $matchingGames[0].AppId -SteamPath $steamPath
                Write-LogMessage "Pass-through mode: Using first match: $($matchingGames[0].Name)" -Type "Info"
            } else {
                Write-Host "`nMultiple games found matching '$GameName':" -ForegroundColor Cyan
                for ($i = 0; $i -lt $matchingGames.Count; $i++) {
                    Write-Host "  [$i] $($matchingGames[$i].Name) (AppID: $($matchingGames[$i].AppId))"
                }
                
                $selection = Read-Host "`nEnter the number of the game to manage [0-$($matchingGames.Count - 1)]"
                if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -lt $matchingGames.Count) {
                    $gameInfo = Get-SteamAppInfo -AppId $matchingGames[[int]$selection].AppId -SteamPath $steamPath
                }
                else {
                    Write-LogMessage "Invalid selection. Exiting." -Type "Error"
                    return 1
                }
            }
        }
    }

    # Display game information
    if ($gameInfo) {
        # Show success message if not in pass-through mode
        if (-not $Pass) {
            Write-LogMessage "Found game: $($gameInfo.Name) (AppID: $($gameInfo.AppId))" -Type "Success"
        }
        
        # In pass-through mode, automatically launch the game
        if ($Pass) {
            Write-LogMessage "Pass-through mode: Launching $($gameInfo.Name) (AppID: $($gameInfo.AppId))" -Type "Info"
            
            # Use the LaunchParameters if provided, otherwise use empty string
            $gameParams = if ($LaunchParameters) { $LaunchParameters } else { "" }
            
            # Launch the game with the specified parameters and account
            $launched = Start-SteamGame -AppId $gameInfo.AppId -LaunchOptions $gameParams -SteamAccountId $SteamAccountId
            
            # Always wait for game to exit in pass-through mode
            if ($launched) {
                $startTime = Get-Date
                $exitSuccess = Wait-SteamGameExit -AppId $gameInfo.AppId -GameInfo $gameInfo
                $endTime = Get-Date
                $playTime = $endTime - $startTime
                
                if ($exitSuccess) {
                    Write-LogMessage "Game '$($gameInfo.Name)' has exited. Play time: $($playTime.Hours)h $($playTime.Minutes)m $($playTime.Seconds)s" -Type "Success"
                } else {
                    Write-LogMessage "Unable to properly detect game exit." -Type "Warning"
                }
            }
            return 0
        }
        
        # Always show details if specifically requested
        if ($ShowDetails) {
            Show-GameDetails -GameInfo $gameInfo -Online:$Online
        } else {
            # Show basic game details unless in pass-through mode
            Write-Host "`n-- Basic Game Information --" -ForegroundColor Cyan
            Write-Host "AppID:       " -NoNewline -ForegroundColor Cyan; Write-Host $gameInfo.AppId
            Write-Host "Name:        " -NoNewline -ForegroundColor Cyan; Write-Host $gameInfo.Name
            Write-Host "Install Path:" -NoNewline -ForegroundColor Cyan; Write-Host $gameInfo.InstallPath
            
            # Show the primary executable if available
            if ($gameInfo.Executable) {
                Write-Host "Executable:  " -NoNewline -ForegroundColor Cyan
                Write-Host (Join-Path -Path $gameInfo.InstallPath -ChildPath $gameInfo.Executable)
            } else {
                # Try to find possible executables
                try {
                    $exeFiles = Get-ChildItem -Path $gameInfo.InstallPath -Filter "*.exe" -File -ErrorAction SilentlyContinue | 
                        Where-Object { -not $_.Name.ToLower().Contains("uninst") } |
                        Sort-Object -Property Length -Descending |
                        Select-Object -First 1
                        
                    if ($exeFiles) {
                        Write-Host "Executable:  " -NoNewline -ForegroundColor Cyan
                        $relativePath = $exeFiles.FullName.Substring($gameInfo.InstallPath.Length + 1)
                        Write-Host $relativePath
                    }
                } catch {
                    # Ignore errors when searching for executables in basic mode
                }
            }
            
            # Display launch hint
            Write-Host "`nTo launch this game, use: " -NoNewline 
            Write-Host ".\SteamLibrarian.ps1 -GameName `"$($gameInfo.Name.Split('\"')[0])`" -LaunchGame" -ForegroundColor Yellow
            Write-Host "For detailed information, use: " -NoNewline 
            Write-Host ".\SteamLibrarian.ps1 -GameName `"$($gameInfo.Name.Split('\"')[0])`" -ShowDetails" -ForegroundColor Yellow
            
            # Add hints for the new parameters
            Write-Host "`nAdvanced launch options:" -ForegroundColor Cyan
            Write-Host "  With Steam account: " -NoNewline 
            Write-Host ".\SteamLibrarian.ps1 -GameName `"$($gameInfo.Name.Split('\"')[0])`" -LaunchGame -SteamAccountId `"YourSteamUsername`"" -ForegroundColor Yellow
            Write-Host "  With launch parameters: " -NoNewline 
            Write-Host ".\SteamLibrarian.ps1 -GameName `"$($gameInfo.Name.Split('\"')[0])`" -LaunchGame -LaunchParameters `"-windowed -width 1920`"" -ForegroundColor Yellow
            Write-Host ""
        }
        
        # Launch the game if requested
        if ($LaunchGame) {
            # Use the LaunchParameters if provided, otherwise use empty string
            $gameParams = if ($LaunchParameters) { $LaunchParameters } else { "" }
            
            # Launch the game with the specified parameters and account
            $launched = Start-SteamGame -AppId $gameInfo.AppId -LaunchOptions $gameParams -SteamAccountId $SteamAccountId
            
            # Always wait for the game to exit when launching
            # This addresses the requirement to wait until the game is closed
            if ($launched) {
                $startTime = Get-Date
                $exitSuccess = Wait-SteamGameExit -AppId $gameInfo.AppId -GameInfo $gameInfo
                $endTime = Get-Date
                $playTime = $endTime - $startTime
                
                if ($exitSuccess) {
                    Write-LogMessage "Game '$($gameInfo.Name)' has exited. Play time: $($playTime.Hours)h $($playTime.Minutes)m $($playTime.Seconds)s" -Type "Success"
                } else {
                    Write-LogMessage "Unable to properly detect game exit." -Type "Warning"
                }
            }
        }
        
        # Copy launch command if requested
        if ($CopyLaunchCommand) {
            Copy-LaunchCommand -AppId $gameInfo.AppId -GameName $gameInfo.Name -ScriptPath $PSCommandPath -SteamAccountId $SteamAccountId -LaunchParameters $LaunchParameters
        }
    }
    else {
        Write-LogMessage "Could not retrieve game information" -Type "Error"
        return 1
    }

    return 0
}
#endregion Main Function

# Call the main function with script parameters
# Handle case when no parameters are provided by defaulting to ListGames
if ($PSBoundParameters.Count -eq 0) {
    LaunchSteamGame -ListGames
} else {
    LaunchSteamGame @PSBoundParameters
}