<#
.SYNOPSIS
    Checks the status of a Satisfactory dedicated server.

.DESCRIPTION
    This script authenticates with the Satisfactory dedicated server API and retrieves
    various status information including server state, player count, and session information.

.PARAMETER ServerUrl
    The base URL of the Satisfactory server API (default: https://twinswords.bullfrogit.net:25571)

.PARAMETER Password
    The administrator password for the server (will be securely prompted)

.PARAMETER OutputFormat
    Output format: Console (default), JSON, or CSV

.EXAMPLE
    .\check-gameserverstatus.ps1
    
.EXAMPLE
    .\check-gameserverstatus.ps1 -OutputFormat JSON

.NOTES
    Author: Assistant
    Date: July 6, 2025
    Requires PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [string]$ServerUrl = "https://twinswords.bullfrogit.net:25571",
    [Parameter(Mandatory=$true)]
    [String]$Password,
    [ValidateSet("Console", "JSON", "CSV")]
    [string]$OutputFormat = "Console",
    [switch]$Help
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to make API calls with error handling
function Invoke-SatisfactoryAPI {
    param(
        [string]$Uri,
        [string]$Method = "POST",
        [hashtable]$Body,
        [string]$AuthToken = $null
    )
    
    try {
        # Set TLS 1.2
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        
        # For PowerShell 5.1, we need to disable certificate validation manually
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            # Disable certificate validation for PowerShell 5.1
            add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        }
        
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        if ($AuthToken) {
            $headers["Authorization"] = "Bearer $AuthToken"
        }
        
        $bodyJson = if ($Body) { $Body | ConvertTo-Json -Depth 10 } else { $null }
        
        # Use -SkipCertificateCheck for PowerShell 6+ or manual certificate handling for 5.1
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $response = Invoke-RestMethod -Uri $Uri -Method $Method -Body $bodyJson -Headers $headers -SkipCertificateCheck
        } else {
            $response = Invoke-RestMethod -Uri $Uri -Method $Method -Body $bodyJson -Headers $headers
        }
        return $response
    }
    catch {
        Write-Error "API call failed: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Error "Inner Exception: $($_.Exception.InnerException.Message)"
        }
        throw
    }
}

# Function to authenticate and get token
function Get-AuthenticationToken {
    param(
        [string]$ServerUrl,
        [String]$Password
    )
    
    Write-ColorOutput "Authenticating with server..." "Yellow"
    
    $plainPassword = $Password
    $authBody = @{
        function = "PasswordLogin"
        data = @{
            MinimumPrivilegeLevel = "Administrator"
            Password = $plainPassword
        }
    }
    
    Write-Verbose "Sending authentication request to $ServerUrl/api/v1"
    $authResponse = Invoke-SatisfactoryAPI -Uri "$ServerUrl/api/v1" -Body $authBody
    
    Write-Verbose "Auth response: $($authResponse | ConvertTo-Json -Depth 3)"
    
    if ($authResponse.data.authenticationToken) {
        Write-ColorOutput "Authentication successful!" "Green"
        return $authResponse.data.authenticationToken
    }
    elseif ($authResponse.errorCode -eq "wrong_password") {
        Write-ColorOutput "ERROR: Incorrect password. Please check your password and try again." "Red"
        throw "Authentication failed - incorrect password"
    }
    else {
        Write-ColorOutput "Authentication response: $($authResponse | ConvertTo-Json -Depth 3)" "Red"
        throw "Authentication failed - no token received"
    }
}

# Function to get server state
function Get-ServerState {
    param(
        [string]$ServerUrl,
        [string]$AuthToken
    )
    
    $stateBody = @{
        function = "QueryServerState"
        data = @{}
    }
    
    return Invoke-SatisfactoryAPI -Uri "$ServerUrl/api/v1" -Body $stateBody -AuthToken $AuthToken
}

# Function to get server options
function Get-ServerOptions {
    param(
        [string]$ServerUrl,
        [string]$AuthToken
    )
    
    $optionsBody = @{
        function = "GetServerOptions"
        data = @{}
    }
    
    return Invoke-SatisfactoryAPI -Uri "$ServerUrl/api/v1" -Body $optionsBody -AuthToken $AuthToken
}

# Function to get advanced game settings
function Get-AdvancedGameSettings {
    param(
        [string]$ServerUrl,
        [string]$AuthToken
    )
    
    $settingsBody = @{
        function = "GetAdvancedGameSettings"
        data = @{}
    }
    
    return Invoke-SatisfactoryAPI -Uri "$ServerUrl/api/v1" -Body $settingsBody -AuthToken $AuthToken
}

# Function to format server status for console output
function Format-ConsoleOutput {
    param(
        [object]$ServerState,
        [object]$ServerOptions,
        [object]$AdvancedSettings
    )
    
    Write-ColorOutput "`n===== SATISFACTORY SERVER STATUS =====" "Cyan"
    Write-ColorOutput "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"
    Write-ColorOutput "Server URL: $ServerUrl" "Gray"
    
    if ($ServerState.data.serverGameState) {
        $state = $ServerState.data.serverGameState
        
        Write-ColorOutput "`n--- Server State ---" "Yellow"
        Write-ColorOutput "Active Session Name: $($state.activeSessionName)" "White"
        Write-ColorOutput "Num Connected Players: $($state.numConnectedPlayers)" "White"
        Write-ColorOutput "Player Limit: $($state.playerLimit)" "White"
        Write-ColorOutput "Tech Tier: $($state.techTier)" "White"
        Write-ColorOutput "Game Phase: $($state.gamePhase -replace '.*[/\\.]', '' -replace '[_\\.].*', '' -replace '_', ' ')" "White"
        Write-ColorOutput "Is Game Running: $($state.isGameRunning)" "White"
        Write-ColorOutput "Is Game Paused: $($state.isGamePaused)" "White"
        Write-ColorOutput "Total Game Duration: $([math]::Round($state.totalGameDuration / 3600, 2)) hours" "White"
        Write-ColorOutput "Average Tick Rate: $([math]::Round($state.averageTickRate, 2)) TPS" "White"
        Write-ColorOutput "Auto Load Session: $($state.autoLoadSessionName)" "White"
        
        # Player status indicator
        if ($state.numConnectedPlayers -gt 0) {
            Write-ColorOutput "Status: $($state.numConnectedPlayers) PLAYER(S) ONLINE" "Green"
        }
        else {
            Write-ColorOutput "Status: NO PLAYERS ONLINE" "Yellow"
        }
        
        # Game running status
        if ($state.isGameRunning) {
            if ($state.isGamePaused) {
                Write-ColorOutput "Game State: RUNNING (PAUSED)" "Yellow"
            } else {
                Write-ColorOutput "Game State: RUNNING" "Green"
            }
        } else {
            Write-ColorOutput "Game State: STOPPED" "Red"
        }
    }
    
    if ($ServerOptions.data.serverOptions -and $ServerOptions.data.serverOptions.Count -gt 0) {
        Write-ColorOutput "`n--- Server Configuration ---" "Yellow"
        $options = $ServerOptions.data.serverOptions
        foreach ($key in $options.Keys) {
            $displayKey = $key -replace '^FG\.', ''
            Write-ColorOutput "${displayKey}: $($options[$key])" "White"
        }
    }
    
    if ($AdvancedSettings.data.advancedGameSettings -and $AdvancedSettings.data.advancedGameSettings.Count -gt 0) {
        Write-ColorOutput "`n--- Advanced Game Settings ---" "Yellow"
        $settings = $AdvancedSettings.data.advancedGameSettings
        Write-ColorOutput "Creative Mode Enabled: $($AdvancedSettings.data.creativeModeEnabled)" "White"
        foreach ($key in $settings.Keys) {
            $displayKey = $key -replace '^FG\.(GameRules|PlayerRules)\.', ''
            Write-ColorOutput "${displayKey}: $($settings[$key])" "White"
        }
    }
    
    Write-ColorOutput "`n=================================" "Cyan"
}

# Function to create status object for JSON/CSV output
function Get-StatusObject {
    param(
        [object]$ServerState,
        [object]$ServerOptions,
        [object]$AdvancedSettings
    )
    
    $statusObj = [PSCustomObject]@{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ServerUrl = $ServerUrl
        ActiveSessionName = $ServerState.data.serverGameState.activeSessionName
        NumConnectedPlayers = $ServerState.data.serverGameState.numConnectedPlayers
        PlayerLimit = $ServerState.data.serverGameState.playerLimit
        TechTier = $ServerState.data.serverGameState.techTier
        GamePhase = ($ServerState.data.serverGameState.gamePhase -replace '.*[/\\.]', '' -replace '[_\\.].*', '' -replace '_', ' ')
        IsGameRunning = $ServerState.data.serverGameState.isGameRunning
        IsGamePaused = $ServerState.data.serverGameState.isGamePaused
        TotalGameDurationHours = [math]::Round($ServerState.data.serverGameState.totalGameDuration / 3600, 2)
        AverageTickRate = [math]::Round($ServerState.data.serverGameState.averageTickRate, 2)
        AutoLoadSessionName = $ServerState.data.serverGameState.autoLoadSessionName
        PlayersOnline = $ServerState.data.serverGameState.numConnectedPlayers -gt 0
        CreativeModeEnabled = $AdvancedSettings.data.creativeModeEnabled
    }
    
    # Add server options as additional properties
    if ($ServerOptions.data.serverOptions -and $ServerOptions.data.serverOptions.Count -gt 0) {
        foreach ($key in $ServerOptions.data.serverOptions.Keys) {
            $cleanKey = $key -replace '^FG\.', 'Config_'
            $statusObj | Add-Member -MemberType NoteProperty -Name $cleanKey -Value $ServerOptions.data.serverOptions[$key] -Force
        }
    }
    
    # Add advanced settings as additional properties
    if ($AdvancedSettings.data.advancedGameSettings -and $AdvancedSettings.data.advancedGameSettings.Count -gt 0) {
        foreach ($key in $AdvancedSettings.data.advancedGameSettings.Keys) {
            $cleanKey = $key -replace '^FG\.(GameRules|PlayerRules)\.', 'Setting_'
            $statusObj | Add-Member -MemberType NoteProperty -Name $cleanKey -Value $AdvancedSettings.data.advancedGameSettings[$key] -Force
        }
    }
    
    return $statusObj
}

# Main execution
try {
    # Show help if requested
    if ($Help) {
        Write-ColorOutput @"
Satisfactory Server Status Checker

USAGE:
    .\check-gameserverstatus.ps1 [-ServerUrl <url>] [-Password <password>] [-OutputFormat <format>] [-Help]

PARAMETERS:
    -ServerUrl     Server API URL (default: https://twinswords.bullfrogit.net:25571)
    -Password      Administrator password
    -OutputFormat  Output format: Console, JSON, or CSV (default: Console)
    -Help          Show this help message

EXAMPLES:
    .\check-gameserverstatus.ps1
    .\check-gameserverstatus.ps1 -OutputFormat JSON
    .\check-gameserverstatus.ps1 -ServerUrl "https://myserver.com:7777"

EXIT CODES:
    0 = Players online
    1 = No players online
    2 = Error occurred
"@ "Cyan"
        exit 0
    }
    
    Write-ColorOutput "Starting Satisfactory Server Status Check..." "Cyan"
    
    # Authenticate
    $authToken = Get-AuthenticationToken -ServerUrl $ServerUrl -Password $Password
    
    # Get server information
    Write-ColorOutput "Retrieving server state..." "Yellow"
    $serverState = Get-ServerState -ServerUrl $ServerUrl -AuthToken $authToken
    
    Write-ColorOutput "Retrieving server options..." "Yellow"
    $serverOptions = Get-ServerOptions -ServerUrl $ServerUrl -AuthToken $authToken
    
    Write-ColorOutput "Retrieving advanced settings..." "Yellow"
    $advancedSettings = Get-AdvancedGameSettings -ServerUrl $ServerUrl -AuthToken $authToken
    
    # Output results based on format
    switch ($OutputFormat) {
        "Console" {
            Format-ConsoleOutput -ServerState $serverState -ServerOptions $serverOptions -AdvancedSettings $advancedSettings
        }
        "JSON" {
            $statusObj = Get-StatusObject -ServerState $serverState -ServerOptions $serverOptions -AdvancedSettings $advancedSettings
            $statusObj | ConvertTo-Json -Depth 10
        }
        "CSV" {
            $statusObj = Get-StatusObject -ServerState $serverState -ServerOptions $serverOptions -AdvancedSettings $advancedSettings
            $statusObj | ConvertTo-Csv -NoTypeInformation
        }
    }
    
    # Set exit code based on server status
    if ($serverState.data.serverGameState.numConnectedPlayers -gt 0) {
        exit 0  # Players online
    } else {
        exit 1  # No players online
    }
}
catch {
    Write-ColorOutput "Error: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack Trace: $($_.ScriptStackTrace)" "Red"
    exit 2  # Error occurred
}
