$ErrorActionPreference = "Stop"

#. a:\Test-Command.ps1

Write-BoxstarterMessage 'Enabling RDP'
Enable-RemoteDesktop
netsh advfirewall firewall add rule name="Remote Desktop" dir=in localport=3389 protocol=TCP action=allow
#reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server' /v fDenyTSConnections /t REG_DWORD /d 0 /f

Write-BoxstarterMessage 'Setting Execution Policy'
Update-ExecutionPolicy -Policy Unrestricted

#if (Test-Command -cmdname 'Uninstall-WindowsFeature') {
#    Write-BoxstarterMessage "Removing unused features..."
#    Remove-WindowsFeature -Name 'Powershell-ISE'
#    Get-WindowsFeature |
#    ? { $_.InstallState -eq 'Available' } |
#    Uninstall-WindowsFeature -Remove
#}


Write-BoxstarterMessage 'Installing updates...'
Install-WindowsUpdate -AcceptEula

Import-Module PackageManagement -Force
Get-PackageSource -Force -ForceBootstrap -Provider chocolatey

Write-BoxstarterMessage 'Installing Guest Additions...'
& cmd /c certutil -addstore -f 'TrustedPublisher' A:\oracle-cert.cer

if (Test-Path e:\VBoxWindowsAdditions.exe) {
  Start-Process E:\VBoxWindowsAdditions.exe -ArgumentList '/S' -Wait
}

Write-BoxstarterMessage "Removing page file"
$pageFileMemoryKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $pageFileMemoryKey -Name PagingFiles -Value ""

if(Test-PendingReboot){ Invoke-Reboot }

Write-Host 'Install puppet agent'
Start-Process msiexec -ArgumentList '/qn /norestart /i https://downloads.puppetlabs.com/windows/puppet-agent-x64-latest.msi' -Wait

Write-Host 'Install salt minion'
$salt_exefile = 'Salt-Minion-2016.3.3-AMD64-Setup.exe'
$salt_url = "https://repo.saltstack.com/windows/$salt_exefile"
Invoke-WebRequest -Uri $salt_url -O $salt_exefile
Start-Process .\\$salt_exefile -ArgumentList '/S /start-service=1' -Wait

Write-Host 'Sdelete things'

Copy-Item a:\sdelete.exe c:\logs
& cmd /c %SystemRoot%\System32\reg.exe ADD HKCU\Software\Sysinternals\SDelete /v EulaAccepted /t REG_DWORD /d 1 /f
& cmd /c C:\logs\sdelete.exe -q -z C:

Write-BoxstarterMessage "Setting up WinRM SSL for ansible and packer"
iex a:\winrm-ssl-ansible.ps1
#netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow

#$enableArgs=@{Force=$true}
#try {
# $command=Get-Command Enable-PSRemoting
#  if($command.Parameters.Keys -contains "skipnetworkprofilecheck"){
#      $enableArgs.skipnetworkprofilecheck=$true
#  }
#}
#catch {
#  $global:error.RemoveAt(0)
#}

#Enable-PSRemoting @enableArgs
#Enable-WSManCredSSP -Force -Role Server
#winrm set winrm/config/client/auth '@{Basic="true"}'
#winrm set winrm/config/service/auth '@{Basic="true"}'
#winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Write-BoxstarterMessage "winrm setup complete"
