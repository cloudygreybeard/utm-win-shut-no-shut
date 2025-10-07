<#
.SYNOPSIS
    Cycles Ethernet adapters and synchronizes system time to resolve network connectivity issues.

.DESCRIPTION
    This script disables and re-enables all Ethernet network adapters, then attempts to synchronize
    the system time. It includes robust retry logic, logging capabilities, and safety features
    to handle network connectivity issues that may occur in virtualized environments.

.PARAMETER DebugMode
    Enables PowerShell debug tracing for troubleshooting.

.PARAMETER WhatIf
    Shows what would happen if the script runs without actually executing the changes.

.PARAMETER LogPath
    Optional path to a log file. If not specified, logging is only to console.

.PARAMETER AdapterPattern
    Pattern to match network adapters (default: "Ethernet*"). Use with caution.

.PARAMETER MaxRetries
    Maximum number of retry attempts for each operation (default: 5).

.PARAMETER SleepDuration
    Duration in seconds to wait between operations (default: 2).

.EXAMPLE
    .\shut-no-shut.ps1
    Runs the script with default settings.

.EXAMPLE
    .\shut-no-shut.ps1 -DebugMode -LogPath "C:\Logs\network-fix.log"
    Runs with debug mode and logs to a file.

.EXAMPLE
    .\shut-no-shut.ps1 -WhatIf
    Shows what the script would do without executing changes.

.NOTES
    Requires administrative privileges to modify network adapters.
    This script will temporarily disrupt network connectivity.
#>

param(
    [switch]$DebugMode,
    [switch]$WhatIf,
    [string]$LogPath,
    [string]$AdapterPattern = "Ethernet*",
    [int]$MaxRetries = 5,
    [int]$SleepDuration = 2
)

# Initialize script variables
$ErrorActionPreference = "Stop"
$script:LogFile = $null
$script:StartTime = Get-Date

# Function to write timestamped log messages
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console
    Write-Host $logMessage -ForegroundColor $Color
    
    # Write to log file if specified
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to test network connectivity
function Test-NetworkConnectivity {
    param([int]$TimeoutSeconds = 5)
    
    try {
        Write-LogMessage "Starting network connectivity test" "DEBUG" "Cyan"
        
        # First check if we have a default gateway
        $defaultGateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Where-Object NextHop -ne "::"
        if (-not $defaultGateway) {
            Write-LogMessage "No default gateway found" "DEBUG" "Yellow"
            return $false
        }
        Write-LogMessage "Default gateway found: $($defaultGateway.NextHop)" "DEBUG" "Green"
        
        # Test basic connectivity with ping
        $testHosts = @("8.8.8.8", "1.1.1.1")
        foreach ($host in $testHosts) {
            Write-LogMessage "Testing ping to $host" "DEBUG" "Cyan"
            try {
                $pingResult = Test-Connection -ComputerName $host -Count 1 -Quiet -ErrorAction Stop
                if ($pingResult) {
                    Write-LogMessage "Ping test to $host successful" "DEBUG" "Green"
                    return $true
                } else {
                    Write-LogMessage "Ping test to $host failed (no response)" "DEBUG" "Yellow"
                }
            }
            catch {
                Write-LogMessage "Ping test to $host failed: $($_.Exception.Message)" "DEBUG" "Yellow"
            }
        }
        
        # Fallback to Test-NetConnection if ping fails
        foreach ($host in $testHosts) {
            Write-LogMessage "Testing HTTP connection to $host" "DEBUG" "Cyan"
            try {
                if (Test-NetConnection -ComputerName $host -Port 80 -InformationLevel Quiet -WarningAction SilentlyContinue) {
                    Write-LogMessage "HTTP test to $host successful" "DEBUG" "Green"
                    return $true
                } else {
                    Write-LogMessage "HTTP test to $host failed (no response)" "DEBUG" "Yellow"
                }
            }
            catch {
                Write-LogMessage "HTTP test to $host failed: $($_.Exception.Message)" "DEBUG" "Yellow"
            }
        }
        
        Write-LogMessage "All connectivity tests failed" "DEBUG" "Red"
        return $false
    }
    catch {
        Write-LogMessage "Network connectivity test failed: $($_.Exception.Message)" "DEBUG" "Red"
        return $false
    }
}

# Function to get network adapters matching pattern
function Get-MatchingAdapters {
    param([string]$Pattern)
    
    try {
        $adapters = Get-NetAdapter -Name $Pattern -ErrorAction Stop
        return $adapters
    }
    catch {
        Write-LogMessage "No network adapters found matching pattern: $Pattern" "WARN" "Yellow"
        return @()
    }
}

# Main script execution
try {
    # Initialize logging
    if ($LogPath) {
        $script:LogFile = $LogPath
        $logDir = Split-Path $LogPath -Parent
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
    }
    
    Write-LogMessage "Starting network adapter cycle and time sync script" "INFO" "Green"
    Write-LogMessage "Script parameters: DebugMode=$DebugMode, WhatIf=$WhatIf, AdapterPattern='$AdapterPattern', MaxRetries=$MaxRetries" "INFO" "Cyan"
    
    # Check for administrative privileges
    if (-not (Test-Administrator)) {
        Write-LogMessage "This script requires administrative privileges. Please run as Administrator." "ERROR" "Red"
        exit 1
    }
    
    # Enable debug mode if requested
    if ($DebugMode) {
        Set-PSDebug -Trace 2
        Write-LogMessage "Debug mode enabled" "DEBUG" "Magenta"
    }
    
    # Get initial network adapters
    $initialAdapters = Get-MatchingAdapters -Pattern $AdapterPattern
    if (-not $initialAdapters) {
        Write-LogMessage "No network adapters found matching pattern: $AdapterPattern" "ERROR" "Red"
        exit 2
    }
    
    Write-LogMessage "Found $($initialAdapters.Count) network adapter(s) matching pattern: $AdapterPattern" "INFO" "Green"
    $initialAdapters | ForEach-Object { Write-LogMessage "  - $($_.Name) ($($_.Status))" "INFO" "Cyan" }
    
    if ($WhatIf) {
        Write-LogMessage "WHATIF: Would disable $($initialAdapters.Count) network adapter(s)" "WHATIF" "Yellow"
        Write-LogMessage "WHATIF: Would wait $SleepDuration seconds" "WHATIF" "Yellow"
        Write-LogMessage "WHATIF: Would attempt to re-enable adapters with $MaxRetries retries" "WHATIF" "Yellow"
        Write-LogMessage "WHATIF: Would attempt time synchronization with $MaxRetries retries" "WHATIF" "Yellow"
        Write-LogMessage "WHATIF: Script execution complete (no changes made)" "WHATIF" "Yellow"
        exit 0
    }
    
    # Test initial network connectivity
    Write-LogMessage "Testing initial network connectivity..." "INFO" "Cyan"
    $initialConnectivity = Test-NetworkConnectivity
    Write-LogMessage "Initial network connectivity: $initialConnectivity" "INFO" $(if ($initialConnectivity) { "Green" } else { "Yellow" })
    
    # Show network adapter status for debugging
    $adapters = Get-MatchingAdapters -Pattern $AdapterPattern
    foreach ($adapter in $adapters) {
        Write-LogMessage "Adapter $($adapter.Name): Status=$($adapter.Status), LinkSpeed=$($adapter.LinkSpeed)" "DEBUG" "Cyan"
    }
    
    # Disable all matching Ethernet adapters
    Write-LogMessage "Disabling network adapter(s)..." "INFO" "Yellow"
    $initialAdapters | Disable-NetAdapter -Confirm:$false -ErrorAction Stop
    Write-LogMessage "Network adapter(s) disabled successfully" "INFO" "Green"
    
    # Wait for system to process the change
    Write-LogMessage "Waiting $SleepDuration seconds for system to process changes..." "INFO" "Cyan"
    Start-Sleep -Seconds $SleepDuration
    
    # Enable all disabled Ethernet adapters with retry logic
    Write-LogMessage "Attempting to re-enable network adapter(s)..." "INFO" "Yellow"
    $attempt = 0
    $success = $false
    
    while (-not $success -and $attempt -lt $MaxRetries) {
        $attempt++
        Write-LogMessage "Enable attempt $attempt of $MaxRetries..." "INFO" "Cyan"
        
        try {
            $disabledAdapters = Get-MatchingAdapters -Pattern $AdapterPattern | Where-Object Status -eq "Disabled"
            if ($disabledAdapters) {
                $disabledAdapters | Enable-NetAdapter -Confirm:$false -ErrorAction Stop
                Write-LogMessage "Enable command executed for $($disabledAdapters.Count) adapter(s)" "INFO" "Green"
            } else {
                Write-LogMessage "No disabled adapters found" "INFO" "Green"
            }
            
            # Wait for adapters to come online
            Start-Sleep -Seconds $SleepDuration
            
            # Check if adapters are now enabled
            $remainingDisabled = Get-MatchingAdapters -Pattern $AdapterPattern | Where-Object Status -eq "Disabled"
            if (-not $remainingDisabled) {
                Write-LogMessage "All network adapter(s) successfully enabled" "INFO" "Green"
                $success = $true
            } else {
                Write-LogMessage "$($remainingDisabled.Count) adapter(s) still disabled. Retrying..." "WARN" "Yellow"
            }
        }
        catch {
            Write-LogMessage "Error while enabling adapters: $($_.Exception.Message)" "WARN" "Yellow"
        }
        
        if (-not $success -and $attempt -lt $MaxRetries) {
            Start-Sleep -Seconds $SleepDuration
        }
    }
    
    if (-not $success) {
        Write-LogMessage "Failed to enable all network adapter(s) after $MaxRetries attempts" "ERROR" "Red"
        exit 3
    }
    
    # Give network stack time to settle
    Write-LogMessage "Waiting for network stack to settle..." "INFO" "Cyan"
    Start-Sleep -Seconds 3
    
    # Test network connectivity after adapter re-enabling
    Write-LogMessage "Testing network connectivity after adapter re-enabling..." "INFO" "Cyan"
    $postEnableConnectivity = Test-NetworkConnectivity
    
    # Show network adapter status after re-enabling
    $adapters = Get-MatchingAdapters -Pattern $AdapterPattern
    foreach ($adapter in $adapters) {
        Write-LogMessage "Adapter $($adapter.Name): Status=$($adapter.Status), LinkSpeed=$($adapter.LinkSpeed)" "DEBUG" "Cyan"
    }
    
    Write-LogMessage "Post-enable network connectivity: $postEnableConnectivity" "INFO" $(if ($postEnableConnectivity) { "Green" } else { "Yellow" })
    
    # Attempt time synchronization with retry logic
    Write-LogMessage "Attempting time synchronization..." "INFO" "Yellow"
    $attempt = 0
    $success = $false
    $failurePattern = "The computer did not resync because no time data was available"
    
    while (-not $success -and $attempt -lt $MaxRetries) {
        $attempt++
        Write-LogMessage "Time sync attempt $attempt of $MaxRetries..." "INFO" "Cyan"
        
        try {
            $syncOutput = w32tm /resync /force 2>&1
            Write-LogMessage "Time sync output: $syncOutput" "INFO" "Cyan"
            
            if ($syncOutput -notmatch $failurePattern) {
                Write-LogMessage "Time synchronization succeeded" "INFO" "Green"
                $success = $true
            } else {
                Write-LogMessage "Time sync failed - no time data available. Retrying..." "WARN" "Yellow"
                Start-Sleep -Seconds $SleepDuration
            }
        }
        catch {
            Write-LogMessage "Error during time sync: $($_.Exception.Message)" "WARN" "Yellow"
            Start-Sleep -Seconds $SleepDuration
        }
    }
    
    if ($success) {
        Write-LogMessage "Time synchronization completed successfully after $attempt attempt(s)" "INFO" "Green"
    } else {
        Write-LogMessage "Time synchronization failed after $MaxRetries attempts" "WARN" "Yellow"
        # Don't exit with error for time sync failure as network may still be working
    }
    
    # Final network connectivity test
    Write-LogMessage "Performing final network connectivity test..." "INFO" "Cyan"
    $finalConnectivity = Test-NetworkConnectivity
    Write-LogMessage "Final network connectivity: $finalConnectivity" "INFO" $(if ($finalConnectivity) { "Green" } else { "Red" })
    
    # Calculate execution time
    $executionTime = (Get-Date) - $script:StartTime
    Write-LogMessage "Script execution completed in $($executionTime.TotalSeconds.ToString('F2')) seconds" "INFO" "Green"
    
    # Set appropriate exit code
    if ($finalConnectivity) {
        Write-LogMessage "Script completed successfully - network connectivity restored" "INFO" "Green"
        exit 0
    } else {
        Write-LogMessage "Script completed with warnings - network connectivity issues may persist" "WARN" "Yellow"
        exit 4
    }
}
catch {
    Write-LogMessage "Unexpected error occurred: $($_.Exception.Message)" "ERROR" "Red"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" "ERROR" "Red"
    exit 5
}
finally {
    # Disable debug mode if it was enabled
    if ($DebugMode) {
        Set-PSDebug -Off
        Write-LogMessage "Debug mode disabled" "DEBUG" "Magenta"
    }
    
    if ($script:LogFile) {
        Write-LogMessage "Log file saved to: $script:LogFile" "INFO" "Cyan"
    }
}
