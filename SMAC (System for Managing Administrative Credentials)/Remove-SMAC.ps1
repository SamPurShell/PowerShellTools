#Uninstall file for SMAC in the Intune Win32 app.

$LogPath = 'C:\Logs'
$LogName = $LogPath + "\Remove-SMAC.log"

Start-Transcript -Path $LogName -Append
Write-Output "Starting removal process"

$ScriptPath = "C:\Program Files (x86)\TechServices\Scripts\SMAC"

Write-Output "Removing $($ScriptPath)"

Remove-Item $ScriptPath -Recurse

Write-Output "Unregistering SMAC Task"

Unregister-ScheduledTask -TaskName "SMAC" -Confirm:$false

Stop-Transcript