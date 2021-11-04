Write-Host "##############################`nInstalling features: Containers, Hyper-V, Hyper-V-PowerShell`n##############################`n"
Install-WindowsFeature Containers
Install-WindowsFeature Hyper-V
Install-WindowsFeature Hyper-V-PowerShell

Write-Host "##############################`nDisabling firewall`n##############################`n"
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

Write-Host "##############################`nRestarting...`n##############################`n"