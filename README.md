# UTM Windows Network Adapter Reset Script

A PowerShell script that cycles network adapters and synchronizes system time to resolve connectivity issues in Windows virtual machines. This script was inspired by the occasional need to perform a "shut/no-shut" operation on Cisco network hardware to resolve connectivity issues.

## Features

- Disables and re-enables Ethernet network adapters
- Synchronizes system time after network restoration
- Retry logic for failed operations
- Administrative privilege checking
- Console and optional file logging
- Preview mode with `-WhatIf` parameter
- Network connectivity verification
- Configurable parameters

## Requirements

- Windows PowerShell 5.1 or PowerShell Core 6.0+
- Administrative privileges (script will check and prompt if needed)
- Windows Time Service (w32tm) for time synchronization

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/cloudygreybeard/utm-win-shut-no-shut.git
   cd utm-win-shut-no-shut
   ```

2. Ensure you have administrative privileges on the target Windows system

## Usage

### Basic Usage
```powershell
# Run with default settings
.\shut-no-shut.ps1

# Run with debug mode and file logging
.\shut-no-shut.ps1 -DebugMode -LogPath "C:\Logs\network-fix.log"

# Preview what the script would do (safe mode)
.\shut-no-shut.ps1 -WhatIf
```

### Advanced Usage
```powershell
# Custom adapter pattern and retry settings
.\shut-no-shut.ps1 -AdapterPattern "Wi-Fi*" -MaxRetries 10 -SleepDuration 3

# Full logging with custom parameters
.\shut-no-shut.ps1 -DebugMode -LogPath "C:\Temp\debug.log" -MaxRetries 3
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-DebugMode` | Switch | False | Enables PowerShell debug tracing |
| `-WhatIf` | Switch | False | Shows what would happen without executing |
| `-LogPath` | String | None | Optional path to log file |
| `-AdapterPattern` | String | "Ethernet*" | Pattern to match network adapters |
| `-MaxRetries` | Integer | 5 | Maximum retry attempts for operations |
| `-SleepDuration` | Integer | 2 | Seconds to wait between operations |

## How It Works

1. Verifies administrative privileges are available
2. Finds network adapters matching the specified pattern
3. Tests initial network connectivity
4. Disables and re-enables network adapters with retry logic
5. Confirms adapters are properly enabled
6. Attempts to sync system time with retry logic
7. Tests final network connectivity and reports results

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success - network connectivity restored |
| 1 | Not running as administrator |
| 2 | No matching network adapters found |
| 3 | Failed to enable adapters after retries |
| 4 | Completed with warnings (time sync issues) |
| 5 | Unexpected error occurred |

## Important Notes

- This script will temporarily disrupt network connectivity
- Must be run as Administrator
- Particularly useful for VMs experiencing network issues
- Requires network connectivity for time synchronization to work

## Troubleshooting

### Common Issues

**"This script requires administrative privileges"**
- Run PowerShell as Administrator
- Right-click PowerShell and select "Run as administrator"

**"No network adapters found"**
- Check the `-AdapterPattern` parameter
- Use `Get-NetAdapter` to list available adapters
- Try patterns like "Wi-Fi*", "*Ethernet*", or "*"

**"Time sync failed"**
- Ensure network connectivity is restored
- Check Windows Time service is running: `Get-Service w32time`
- Verify time servers are accessible

### Debug Mode
Use `-DebugMode` for detailed troubleshooting:
```powershell
.\shut-no-shut.ps1 -DebugMode -LogPath "debug.log"
```

## Contributing

Contributions are welcome. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script modifies network adapter settings and may temporarily disrupt network connectivity. Use with caution in production environments. The authors are not responsible for any network downtime or connectivity issues that may result from using this script.

## Support

If you encounter issues or have questions:

1. Check the [Issues](https://github.com/cloudygreybeard/utm-win-shut-no-shut/issues) page
2. Create a new issue with detailed information about your problem
3. Include system information, error messages, and steps to reproduce

## Related Projects

- [UTM](https://github.com/utmapp/UTM) - Virtualization platform for macOS
- [Windows Time Service](https://docs.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service) - Microsoft documentation
