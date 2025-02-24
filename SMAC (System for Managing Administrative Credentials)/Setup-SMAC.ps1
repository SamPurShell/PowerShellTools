#This is used as the setup/installation file for the win32 app in Intune when deploying to clients

$LogPath = 'C:\Logs'
$LogName = $LogPath + "\Setup-SMAC.log"

If ((Test-Path $LogPath) -eq $false)
{
    New-Item -Path c:\Logs -ItemType Directory
}

Start-Transcript -Path $LogName -Append

$ScriptPath = "C:\Program Files (x86)\TechServices\Scripts\SMAC"

Write-Output "Checking for script paths"
If ((Test-Path $ScriptPath) -eq $false)
{
    Write-Output "Script path did not exist, building it now $($ScriptPath)"
    New-Item $ScriptPath -ItemType Directory 
}

Write-Output "Copying all SMAC tool files to script path"

$Files = Get-ChildItem $PSScriptroot

foreach ($File in $Files)
{
    Write-Output "Copying $($file.Name) to $($ScriptPath)"
    Copy-Item -Path $File.FullName -Destination $ScriptPath
}

$ScriptLaunch = $ScriptPath + "\SMAC-Client.ps1"

#Check for existing task and remove it if it's there
If ((Get-ScheduledTask 'SMAC' -ErrorAction SilentlyContinue))
{
    Write-Output "Found existing task, removing it now..."
    Unregister-ScheduledTask 'SMAC' -Confirm:$false
}


Write-Output "Building scheduled task for SMAC process to run every 30 days."
Register-ScheduledTask -TaskName SMAC -Xml '<?xml version="1.0" encoding="UTF-16"?><Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"><RegistrationInfo><Author>CORNEAGEN\HelpdeskSPurcell</Author><Description>Local Admin SMAC Tool</Description><URI>\SMAC</URI></RegistrationInfo><Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals><Settings><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><RestartOnFailure><Count>16</Count><Interval>PT3H</Interval></RestartOnFailure><StartWhenAvailable>true</StartWhenAvailable><IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings><UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine></Settings><Triggers><CalendarTrigger><StartBoundary>2024-03-13T10:00:00-07:00</StartBoundary><ScheduleByWeek><WeeksInterval>4</WeeksInterval><DaysOfWeek><Wednesday /></DaysOfWeek></ScheduleByWeek></CalendarTrigger></Triggers><Actions Context="Author"><Exec><Command>powershell.exe</Command><Arguments>-ExecutionPolicy Bypass -File "C:\Program Files (x86)\TechServices\Scripts\SMAC\SMAC-Client.ps1"</Arguments></Exec><Exec><Command>C:\Program Files (x86)\TechServices\Scripts\SMAC\RetryFile.exe</Command><Arguments>-ExecutionPolicy Bypass exit</Arguments></Exec></Actions></Task>
'

Write-Output "Initiating first run of the SMAC script"

Start-ScheduledTask -TaskName "SMAC"

Stop-Transcript