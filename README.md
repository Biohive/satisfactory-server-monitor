# Satisfactory Server Status Checker

A comprehensive PowerShell script for monitoring Satisfactory dedicated server status via the API.

## Features

- **Authentication**: Securely authenticates with the Satisfactory server API
- **Server Status**: Retrieves detailed server state information including:
  - Active session name and player count
  - Game phase and tech tier
  - Server performance metrics (tick rate)
  - Game duration and pause state
- **Configuration**: Shows server options and advanced game settings
- **Multiple Output Formats**: Console (default), JSON, and CSV
- **Exit Codes**: Returns meaningful exit codes for automation
- **Error Handling**: Comprehensive error handling with detailed messages

## Usage

### Basic Usage
```powershell
.\check-gameserverstatus.ps1
```

### With Custom Server URL
```powershell
.\check-gameserverstatus.ps1 -ServerUrl "https://yourserver.com:7777"
```

### JSON Output (for automation/monitoring)
```powershell
.\check-gameserverstatus.ps1 -OutputFormat JSON
```

### CSV Output (for logging/analysis)
```powershell
.\check-gameserverstatus.ps1 -OutputFormat CSV
```

## Parameters

- **ServerUrl**: The base URL of the Satisfactory server API (default: https://twinswords.bullfrogit.net:25571)
- **Password**: The administrator password for the server (default: configured in script)
- **OutputFormat**: Output format - Console (default), JSON, or CSV

## Exit Codes

- **0**: Players are online
- **1**: No players online (server running but empty)
- **2**: Error occurred (authentication failed, server unreachable, etc.)

## Examples

### Console Output
Shows a formatted, human-readable status report with colored output:
```
===== SATISFACTORY SERVER STATUS =====
Timestamp: 2025-07-06 14:11:04
Server URL: https://twinswords.bullfrogit.net:25571

--- Server State ---
Active Session Name: CPA
Num Connected Players: 1
Player Limit: 6
Tech Tier: 9
Game Phase: GP_Project_Assembly_Phase_4
Is Game Running: True
Is Game Paused: False
Total Game Duration: 487.68 hours
Average Tick Rate: 29.95 TPS
Auto Load Session: CPA
Status: 1 PLAYER(S) ONLINE
Game State: RUNNING
=================================
```

### JSON Output
Perfect for integration with monitoring systems:
```json
{
    "Timestamp": "2025-07-06 14:11:04",
    "ServerUrl": "https://twinswords.bullfrogit.net:25571",
    "ActiveSessionName": "CPA",
    "NumConnectedPlayers": 1,
    "PlayerLimit": 6,
    "TechTier": 9,
    "GamePhase": "GP_Project_Assembly_Phase_4",
    "IsGameRunning": true,
    "IsGamePaused": false,
    "TotalGameDurationHours": 487.68,
    "AverageTickRate": 29.95,
    "AutoLoadSessionName": "CPA",
    "PlayersOnline": true,
    "CreativeModeEnabled": false
}
```

## Automation Examples

### Windows Task Scheduler
Create a scheduled task to run every 5 minutes and log status:
```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\check-gameserverstatus.ps1" -OutputFormat JSON >> server-log.json
```

### Monitoring Script
Check if players are online and send notifications:
```powershell
$result = & ".\check-gameserverstatus.ps1" -OutputFormat JSON | ConvertFrom-Json
if ($result.PlayersOnline) {
    Write-Host "Players are online!" -ForegroundColor Green
} else {
    Write-Host "Server is empty" -ForegroundColor Yellow
}
```

### Performance Monitoring
Monitor server performance and alert on low TPS:
```powershell
$status = & ".\check-gameserverstatus.ps1" -OutputFormat JSON | ConvertFrom-Json
if ($status.AverageTickRate -lt 25) {
    Write-Warning "Server TPS is low: $($status.AverageTickRate)"
}
```

## Requirements

- PowerShell 5.1 or later
- Network access to the Satisfactory server API
- Administrator credentials for the Satisfactory server

## Security Notes

- The script handles SSL certificate validation for self-signed certificates
- Passwords are passed as plain text parameters (consider using SecureString for production)
- The script exits with appropriate codes for monitoring integration

## API Endpoints Used

- `PasswordLogin`: Authenticates and retrieves access token
- `QueryServerState`: Gets current server state and player information
- `GetServerOptions`: Retrieves server configuration options
- `GetAdvancedGameSettings`: Gets advanced game settings and creative mode status
