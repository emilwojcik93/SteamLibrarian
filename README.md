# SteamLibrarian

A powerful PowerShell script for managing your Steam game library from the command line with special support for Apollo/Sunshine remote streaming.

## Description

SteamLibrarian is an advanced Steam game management tool for Windows PowerShell that provides comprehensive functionality to manage your Steam game library including:

- Finding and launching installed Steam games by name or AppID
- Retrieving detailed game information (install location, executables, size, etc.)
- Launching games via Steam protocol with monitoring from start to exit
- Direct integration with streaming services like Sunshine/Apollo
- Process monitoring and detailed statistics for game sessions
- Generating launch commands for remote streaming setups

SteamLibrarian works with native Steam installations on Windows without requiring additional software or external web services.

## Prerequisites

- PowerShell 5.0 or later
- Steam Client installed on Windows
- Administrator privileges are NOT required for basic functionality

## Installation

### Option 1: Download Script Directly

```powershell
# Using Invoke-RestMethod to download the script
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/emilwojcik93/SteamLibrarian/main/SteamLibrarian.ps1" -OutFile "SteamLibrarian.ps1"
```

### Option 2: Download for Apollo/Sunshine Integration

To install SteamLibrarian specifically for Apollo integration:

```powershell
# Create script directory if it doesn't exist
$apolloScriptPath = "C:\Program Files\Apollo\scripts"
if (-not (Test-Path $apolloScriptPath)) {
    New-Item -ItemType Directory -Path $apolloScriptPath -Force
}

# Download script to Apollo scripts directory (requires admin rights)
Start-Process powershell -Verb RunAs -ArgumentList "-Command", "Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/emilwojcik93/SteamLibrarian/main/SteamLibrarian.ps1' -OutFile '$apolloScriptPath\SteamLibrarian.ps1'"
```

### Option 3: Save to Documents PowerShell Scripts Folder

Install to your personal PowerShell scripts folder in Documents:

```powershell
# Create PowerShell scripts folder in Documents if it doesn't exist
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
$scriptsFolder = Join-Path $documentsPath "PowerShell\Scripts"
if (-not (Test-Path $scriptsFolder)) {
    New-Item -ItemType Directory -Path $scriptsFolder -Force
}

# Download script to Documents PowerShell Scripts folder
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/emilwojcik93/SteamLibrarian/main/SteamLibrarian.ps1" -OutFile "$scriptsFolder\SteamLibrarian.ps1"

Write-Host "Script installed to $scriptsFolder\SteamLibrarian.ps1"
Write-Host "You can run it with: & '$scriptsFolder\SteamLibrarian.ps1' -ListGames"
```

> [!NOTE]  
> If you encounter execution policy issues, you may need to change the execution policy:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
> ```

## Basic Usage

### Run Without Parameters (Shows Accounts and Games)

```powershell
# Simply running the script without parameters shows both accounts and games
.\SteamLibrarian.ps1
```

### List All Steam Games

```powershell
.\SteamLibrarian.ps1 -ListGames
```

### Find a Game by Partial Name

```powershell
.\SteamLibrarian.ps1 -GameName "Half-Life"
```

### Launch a Game

```powershell
.\SteamLibrarian.ps1 -GameName "Cyberpunk" -LaunchGame
```

### Launch a Game with Specific Steam Account

```powershell
.\SteamLibrarian.ps1 -GameName "Portal" -LaunchGame -SteamAccountId "YourSteamUsername"
```

### Launch a Game with Custom Parameters

```powershell
.\SteamLibrarian.ps1 -GameName "Cyberpunk" -LaunchGame -LaunchParameters "-windowed -width 1920 -height 1080"
```

### Show Detailed Game Information

```powershell
.\SteamLibrarian.ps1 -GameName "Portal" -ShowDetails
```

### Quick Launch (Pass-Through Mode)

```powershell
.\SteamLibrarian.ps1 -Pass -GameName "Skyrim"
```

### Online Information

```powershell
.\SteamLibrarian.ps1 -GameName "Elden Ring" -ShowDetails -Online
```

### List All Steam Accounts

```powershell
.\SteamLibrarian.ps1 -ListSteamAccountIds
```

### Generate Apollo/Sunshine Launch Command

```powershell
.\SteamLibrarian.ps1 -GameName "SnowRunner" -CopyLaunchCommand
```

## Script Parameters

| Parameter    | Description                                                |
|-------------|------------------------------------------------------------|
| `-AppId`     | Steam AppID for direct game access                         |
| `-GameName`  | Search for a game by name (partial name supported)         |
| `-LaunchGame` | Launch the game after finding it                           |
| `-WaitForExit` | Wait for the game to close after launching                 |
| `-ShowDetails` | Show comprehensive game information                        |
| `-ListGames` | Display all installed Steam games                          |
| `-ListSteamAccountIds` | List all Steam accounts and show default account      |
| `-Pass`      | Quick pass-through mode with minimal output                |
| `-Online`    | Enable online information fetching via Steam API           |
| `-CopyLaunchCommand` | Copy Apollo/Sunshine integration commands to clipboard |
| `-SteamAccountId` | Specify a Steam Account ID or nickname to use when launching |
| `-LaunchParameters` | Additional parameters to pass to the game when launching |

## Steam Account Management

SteamLibrarian now provides advanced features for managing multiple Steam accounts:

### Listing Available Steam Accounts

You can view all Steam accounts that have logged in on your computer:

```powershell
.\SteamLibrarian.ps1 -ListSteamAccountIds
```

This will display a list of all accounts, highlighting the default (currently active) account.

### Running Games with Specific Steam Accounts

When you have multiple Steam accounts, you can specify which account to use when launching a game:

```powershell
.\SteamLibrarian.ps1 -GameName "Portal" -LaunchGame -SteamAccountId "YourSteamUsername"
```

#### How Steam Account Selection Works

1. When you specify `-SteamAccountId`, the script checks if Steam is already running
2. If Steam is running, it will close it and restart with the specified account
3. If Steam is not running, it will start Steam with the specified account credentials
4. The game will then launch under that Steam account

This is particularly useful if:
- You have multiple Steam accounts with different game libraries
- You share a computer with family members but want to launch your own games
- You need to switch between different regional accounts

### Default Behavior

If you don't specify a `-SteamAccountId`:
- The script will use whatever Steam account is currently active or was last logged in
- No Steam restart is performed

### Notes on Account Recognition

- The script reads from Steam's `loginusers.vdf` file to identify available accounts
- Account recognition works with both account names (login names) and display names
- The current active (default) account is determined from the Windows registry
- All game libraries associated with all accounts are shown when using `-ListGames`

## Integration with Sunshine/Apollo

SteamLibrarian works perfectly with Sunshine/Apollo for game streaming. Here's how to use it:

### Step 1: Identifying Games for Apollo Integration

First, identify the games you want to add to Apollo:

```powershell
# List all installed games to find the ones you want to stream
.\SteamLibrarian.ps1 -ListGames

# Get detailed information about a specific game
.\SteamLibrarian.ps1 -GameName "SnowRunner" -ShowDetails
```

### Step 2: Test Game Launch Manually

Before adding to Apollo, test the game launch manually to ensure it works properly:

```powershell
# Launch the game to test it works correctly
.\SteamLibrarian.ps1 -GameName "SnowRunner" -LaunchGame
```

> [!IMPORTANT]
> - Always test games manually first to ensure they start correctly
> - Initial game setup should be done manually to avoid installer/dependency issues
> - Games with external launchers (Epic, Ubisoft Connect, etc.) may not work properly with automated launching

### Step 3: Generate Apollo Launch Command

```powershell
# Generate the Apollo integration command
.\SteamLibrarian.ps1 -GameName "SnowRunner" -CopyLaunchCommand

# Generate with Steam account
.\SteamLibrarian.ps1 -GameName "SnowRunner" -CopyLaunchCommand -SteamAccountId "YourSteamUsername"

# Generate with custom launch parameters
.\SteamLibrarian.ps1 -GameName "SnowRunner" -CopyLaunchCommand -LaunchParameters "-windowed -width 1920 -height 1080"
```

This will copy a command to your clipboard in this format:
```
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\SteamLibrarian.ps1" -AppId 1465360 -LaunchGame -WaitForExit
```

Or with custom parameters:
```
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\SteamLibrarian.ps1" -AppId 1465360 -LaunchGame -WaitForExit -SteamAccountId "YourSteamUsername" -LaunchParameters "-windowed -width 1920 -height 1080"
```

### Step 4: Adding to Apollo/Sunshine

1. Open your Sunshine or Apollo configuration
2. Add a new application with these settings:

| Field | Value |
|-------|-------|
| Application Name | SnowRunner |
| Command | powershell.exe -ExecutionPolicy Bypass -File "C:\Program Files\Apollo\scripts\SteamLibrarian.ps1" -AppId 1465360 -LaunchGame -WaitForExit |

For advanced use cases, you can include Steam account selection and custom launch parameters:

| Application Name | SnowRunner (Windowed Mode) |
| Command | powershell.exe -ExecutionPolicy Bypass -File "C:\Program Files\Apollo\scripts\SteamLibrarian.ps1" -AppId 1465360 -LaunchGame -WaitForExit -LaunchParameters "-windowed -width 1920 -height 1080" |

> [!WARNING]
> You must use the **Command** field, not "Detached Command". Using "Detached Command" will cause the process to not be observed by Apollo/Sunshine, and the streaming session will not end automatically when the game and script exits.

The `-LaunchGame -WaitForExit` parameters ensure that:
1. The game starts automatically
2. Apollo/Sunshine knows when the game exits to stop streaming

### Example: Automating Multiple Games

You can create a batch script to add multiple games at once to Sunshine/Apollo:

```powershell
# Add popular games automatically
$games = @(
    @{Name = "Cyberpunk 2077"; AppId = 1091500},
    @{Name = "Baldur's Gate 3"; AppId = 1086940},
    @{Name = "Elden Ring"; AppId = 1245620}
)

foreach ($game in $games) {
    # Extract game information
    $details = & "$PSScriptRoot\SteamLibrarian.ps1" -AppId $game.AppId
    
    if ($details) {
        # Generate Apollo command
        & "$PSScriptRoot\SteamLibrarian.ps1" -AppId $game.AppId -CopyLaunchCommand
        Write-Host "Generated command for $($game.Name). Now paste into Apollo config."
        Read-Host "Press Enter to continue to next game"
    }
}
```

## Troubleshooting Apollo Integration

### Known Issues with Game Launchers

Some games have external launchers that may cause issues with Apollo/Sunshine integration:

- **Games with external launchers**: Games that require Epic Games Launcher, EA App, Ubisoft Connect, etc. may not launch properly through Apollo.
- **First-time setup**: Games that require initial setup, DLC installation, or dependency installations should be run manually first.
- **Windows UAC Prompts**: Games that trigger UAC (User Account Control) prompts may not work correctly with Apollo integration.

### Process Detection Method

SteamLibrarian uses a multi-layered approach to identify and monitor game processes:

1. **Known Game Executables**: The script first checks for executables in the game's installation directory and prioritizes monitoring those processes
2. **Steam Registry**: Monitors the Steam registry entries for running games
3. **Window Handle Detection**: Falls back to detecting new processes with window handles as a last resort

This prioritized approach greatly improves reliability with games that:
- Launch multiple processes
- Use setup/dependency installers
- Have external launchers

### Solutions

1. **Incorrect Process Detection**: If SteamLibrarian incorrectly detects launcher processes or installers as the main game:
   - Launch the game manually at least once to complete all setup steps
   - Look for command line options to skip launchers if available
   - The script will now prioritize monitoring executables from the game's actual install directory

2. **Test Thoroughly**: Always test games with `-LaunchGame -WaitForExit` parameters before adding to Apollo

3. **External Launcher Games**: For games with problematic launchers, consider these alternatives:
   - Launch Steam Big Picture mode through Apollo instead of specific games
   - Use the Steam Link app as an alternative to Apollo for Steam games

## Script Components

### Core Functions

- **Get-SteamPath**: Locates Steam installation directory
- **Get-SteamLibraryFolders**: Finds all Steam library locations
- **Get-InstalledSteamGames**: Discovers installed games through manifest files
- **Get-SteamAppInfo**: Retrieves detailed information about a specific game
- **Start-SteamGame**: Launches a Steam game using the steam:// protocol
- **Wait-SteamGameExit**: Monitors game process from launch to exit
- **Show-GameDetails**: Displays comprehensive information about a game
- **Copy-LaunchCommand**: Generates and copies Apollo launch commands

### Logging Functions

- **Write-LogMessage**: Formats and outputs log messages with consistent styling and timestamps

### Game Management

The script handles several complex tasks:
1. Detecting Steam installation locations
2. Parsing game manifest files
3. Managing game launch and monitoring
4. Collecting system resource usage during gameplay
5. Providing detailed game information from local and online sources

## Examples

### Basic Game Launch
```powershell
PS> .\SteamLibrarian.ps1 -GameName "Half-Life" -LaunchGame
[2025-05-07 22:15:41] [Info] Found Steam at: c:/program files (x86)/steam
[2025-05-07 22:15:41] [Info] Looking for games matching name: 'Half-Life'
[2025-05-07 22:15:41] [Success] Found game: Half-Life (AppID: 70)

-- Basic Game Information --
AppID:       70
Name:        Half-Life
Install Path: c:\program files (x86)\steam\steamapps\common\Half-Life

[2025-05-07 22:15:42] [Info] Launching Steam game with AppID: 70
[2025-05-07 22:15:42] [Info] Waiting for game to start...
[2025-05-07 22:15:44] [Success] Game detected as running via Steam registry
[2025-05-07 22:15:44] [Info] Game is running. Waiting for it to exit...
[2025-05-07 22:20:17] [Success] Game has exited
[2025-05-07 22:20:17] [Success] Game 'Half-Life' has exited. Play time: 0h 4m 33s
```

### Quick Launch with Process Info
```powershell
PS> .\SteamLibrarian.ps1 -Pass -GameName "Expeditions"
[2025-05-07 22:09:05] [Info] Pass-through mode: Launching Expeditions: A MudRunner Game (AppID: 2477340)
[2025-05-07 22:09:05] [Info] Launching Steam game with AppID: 2477340
[2025-05-07 22:09:05] [Info] Waiting for game to start...
[2025-05-07 22:09:08] [Success] Game detected as running via Steam registry

=== Detected Game Process ===
Process Name: Expeditions.exe
Process ID:   34256
Window Title: Expeditions: A MudRunner Game
Executable:   C:\Program Files (x86)\Steam\steamapps\common\Expeditions A MudRunner Game\Expeditions.exe
Start Time:   5/7/2025 10:09:07 PM
Memory Usage: 1245.67 MB
==========================

[2025-05-07 22:09:08] [Info] Game is running. Waiting for it to exit...
[2025-05-07 22:09:23] [Success] Game has exited
[2025-05-07 22:09:23] [Success] Game 'Expeditions: A MudRunner Game' has exited. Play time: 0h 0m 18s
```

### Generate Apollo Integration Command

```powershell
PS> .\SteamLibrarian.ps1 -GameName "SnowRunner" -CopyLaunchCommand
[2025-05-07 22:45:10] [Info] Found Steam at: c:/program files (x86)/steam
[2025-05-07 22:45:10] [Info] Looking for games matching name: 'SnowRunner'
[2025-05-07 22:45:10] [Success] Found game: SnowRunner (AppID: 1465360)
[2025-05-07 22:45:11] [Success] Launch command for 'SnowRunner' copied to clipboard!

=== APOLLO/SUNSHINE INTEGRATION COMMAND ===
Command copied to clipboard:
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\ewojcik\Documents\SteamLibrarian\SteamLibrarian.ps1" -AppId 1465360 -LaunchGame -WaitForExit

For Apollo/Sunshine configuration:
----------------------------------------
Application Name: SnowRunner
Command: powershell.exe -ExecutionPolicy Bypass -File "C:\Users\ewojcik\Documents\SteamLibrarian\SteamLibrarian.ps1" -AppId 1465360 -LaunchGame -WaitForExit
----------------------------------------

IMPORTANT NOTES:
1. Games with external launchers (Epic, Ubisoft Connect, etc.) may not work properly
2. Initial game setup should be done manually to avoid installer/dependency issues
3. Test the game launch manually before adding to Apollo/Sunshine
=======================================
```

### Example config:
apps.json
```json
        {
            "allow-client-commands": true,
            "auto-detach": true,
            "cmd": "powershell.exe -ExecutionPolicy Bypass -File \"C:\\path\\to\\SteamLibrarian.ps1\" -AppId 1465360 -LaunchGame -WaitForExit",
            "elevated": false,
            "exclude-global-prep-cmd": false,
            "exit-timeout": 1,
            "image-path": "C:\\Program Files\\Apollo\\config/covers/igdb_107215.png",
            "name": "SnowRunner",
            "output": "",
            "per-client-app-identity": false,
            "scale-factor": 100,
            "use-app-identity": false,
            "uuid": "24826EAD-965A-B026-9C8D-F77F5862D05B",
            "virtual-display": true,
            "wait-all": true
        }
```

Example with custom parameters:
```json
        {
            "allow-client-commands": true,
            "auto-detach": true,
            "cmd": "powershell.exe -ExecutionPolicy Bypass -File \"C:\\path\\to\\SteamLibrarian.ps1\" -AppId 1465360 -LaunchGame -WaitForExit -SteamAccountId \"YourSteamUsername\" -LaunchParameters \"-windowed -width 1920 -height 1080\"",
            "elevated": false,
            "exclude-global-prep-cmd": false,
            "exit-timeout": 1,
            "image-path": "C:\\Program Files\\Apollo\\config/covers/igdb_107215.png",
            "name": "SnowRunner (Windowed)",
            "output": "",
            "per-client-app-identity": false,
            "scale-factor": 100,
            "use-app-identity": false,
            "uuid": "24826EAD-965A-B026-9C8D-F77F5862D05B",
            "virtual-display": true,
            "wait-all": true
        }
```

### Demo:
https://github.com/user-attachments/assets/5458d21c-2e08-4c1f-8082-d3437f58dc6c

## Advanced Usage

### Combining with Other Tools

SteamLibrarian can be combined with other PowerShell scripts or automation tools:

```powershell
# Example: Start Discord before launching a game
Start-Process "discord:///"
Start-Sleep -Seconds 5
.\SteamLibrarian.ps1 -Pass -GameName "Destiny 2"
```

### Creating Game-Specific Shortcuts

```powershell
$shortcutPath = "$env:USERPROFILE\Desktop\Play Cyberpunk 2077.lnk"
$powershellPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$scriptPath = "C:\Scripts\SteamLibrarian.ps1"
$arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`" -Pass -AppId 1091500"

$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powershellPath
$shortcut.Arguments = $arguments
$shortcut.Save()
```

## Notes

- SteamLibrarian uses a combination of registry checks, manifest file parsing, and process monitoring to provide a comprehensive Steam game management experience.
- For optimal experience with Sunshine/Apollo, use the `-LaunchGame -WaitForExit` parameters to ensure proper game lifecycle management.
- The script respects your existing Steam installation and does not modify any Steam settings or files.

## Troubleshooting

If you encounter issues:

1. **Script Won't Run**: Check your PowerShell execution policy:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   ```

2. **Steam Games Not Found**: Verify Steam is installed and games are properly installed through Steam

3. **Game Won't Launch**: Try launching directly through Steam to troubleshoot any Steam-specific issues

4. **Games Exit Immediately**: Some games might have dependencies or require manual setup first

## License

This script is provided as-is, free to use, modify, and distribute.

## Credits

- Created with assistance from GitHub Copilot
- Steam protocol documentation: [Steam Browser Protocol](https://developer.valvesoftware.com/wiki/Steam_browser_protocol)
