# How to install windows 11 without internet
During windows installation, when windows ask for wifi
 - Press: MAJ + F10
 - Type: OOBE\BYPASSNRO
The PC will reboot and a new button will appear during wifi setup: "I don't have internet"

# How to apply the configuration
Run the following commands in an elevated (Administrator) PowerShell:

```powershell
.\apply_registry.ps1
.\configure_powershell.ps1
```

