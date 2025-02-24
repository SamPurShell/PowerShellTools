#Check if scheduled task exists already, create it if it doesn't already exist

$TaskCheck = Get-ScheduledTask -TaskName "Add Printers - SEA" -ErrorAction SilentlyContinue

If ($Null -eq $TaskCheck)
{
$scriptfilecheck = Test-path -Path "C:\Program Files (x86)\TechServices\Scripts\Add-Printers\SEA.ps1"
If ($Null -eq $scriptfilecheck)
{
New-item -Path "C:\Program Files (x86)\TechServices\Scripts\Add-Printers\SEA.ps1" -ItemType "file" -value "$NetworkCheck = Test-NetConnection -ComputerName "SEACGDC01.corneagen.local"
If ($NetworkCheck.PingSucceeded -eq $True)
{

$PrintServer = "SEACGPS01.corneagen.local"
$PrintServerPrinters = get-printer -ComputerName $PrintServer
$LocalPrinterInfo = Get-Printer | where {$_.shared -like "True"}

ForEach ($ServerPrinter in $PrintServerPrinters.Name)
{

    If ($localprinterInfo.ShareName -notcontains $serverprinter)
    {
    write-host "adding $($serverprinter)"
    $PrinterPath = '\\' + $(($PrintServer) + '\' + $($ServerPrinter))
    Add-Printer -ConnectionName $printerpath
    }
    Else{Write-Host "Printer $($serverprinter) is already installed"}
    }
}"
}
}





$actions = New-ScheduledTaskAction -Execute powershell.exe -Argument '-ExecutionPolicy Bypass -File "\\corneagen.local\shares"'
$Trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Wednesday -At 10am
$Principal = New-ScheduledTaskPrincipal "Users" 
$Settings = New-ScheduledTaskSettingsSet -RestartCount 16 -RestartInterval (New-TimeSpan -Minutes 180) -AllowStartIfOnBatteries 
$Task = New-ScheduledTask -Action $Actions -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Local Admin SMAC Tool"
Register-ScheduledTask 'SMAC' -InputObject $Task
}




$NetworkCheck = Test-NetConnection -ComputerName "SEACGDC01.corneagen.local"
If ($NetworkCheck.PingSucceeded -eq $True)
{

$PrintServer = "SEACGPS01.corneagen.local"
$PrintServerPrinters = get-printer -ComputerName $PrintServer
$LocalPrinterInfo = Get-Printer | where {$_.shared -like "True"}

ForEach ($ServerPrinter in $PrintServerPrinters.Name)
{

    If ($localprinterInfo.ShareName -notcontains $serverprinter)
    {
    write-host "adding $($serverprinter)"
    $PrinterPath = '\\' + $(($PrintServer) + '\' + $($ServerPrinter))
    Add-Printer -ConnectionName $printerpath
    }
    Else{Write-Host "Printer $($serverprinter) is already installed"}
    }
}