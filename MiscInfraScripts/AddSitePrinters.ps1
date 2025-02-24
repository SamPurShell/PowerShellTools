#With domainless computers, users can no longer search for printers to add in "Add printers and scanners" in Windows. 
#This script is deployed from Intune and embeds a script and scheduled task to run at user logon, which checks if the computer is on the corporate network and if it is, compares locally installed printers to printers on their home sites print server and add connections to any that are missing.
#One of these scripts exists for each office location and members are assigned based on dynamic AAD groups.  

$TaskCheck = Get-ScheduledTask -TaskName "Add Printers - {Office Location}" -ErrorAction SilentlyContinue
$ScriptFilePath = "C:\Program Files (x86)Scripts\Add-Printers\{Office Location}.ps1"
$ScriptFilePathCheck = Test-path -Path $ScriptFilePath


If ($False -eq $ScriptFilePathCheck)
{
$ScriptContents = 
'$TimeStamp = Get-Date -Format "hh:mm:ss-MM-dd-yyyy"
$LogPath = "C:\Users\" + $Env:Username + "\Logs\Add Printers - {Office Location}.log"
$LogPathTest = Test-Path -Path $LogPath
If ($LogPathTest -ne $True)
    {
    New-Item -Path $logpath -ItemType file -force
    }
Start-Transcript $LogPath -append -Force
Write-Output "$($timeStamp) Run Started!"
write-host "Testing corporate network connection..." 
$NetworkCheck = Test-NetConnection -ComputerName "DC01.example.local"
If ($NetworkCheck.PingSucceeded -eq $False)
{
Write-host "Network connection failed, exiting script. Corporate network connection must be established to add connections to print server."
} 
If ($NetworkCheck.PingSucceeded -eq $True)
{
write-host "Network connection test succeeded, checking printers on Seattle print server..."
$PrintServer = "PrintServer.example.local"
$PrintServerPrinters = get-printer -ComputerName $PrintServer
$LocalPrinterInfo = Get-Printer | where {$_.shared -like "True"}

ForEach ($ServerPrinter in $PrintServerPrinters.Name)
{

    If ($localprinterInfo.ShareName -notcontains $serverprinter)
    {
    write-host "adding $($serverprinter)"
    $PrinterPath = "\\" + $(($PrintServer) + "\" + $($ServerPrinter))
    Add-Printer -ConnectionName $printerpath
    }
    Else{Write-Host "Printer $($serverprinter) is already installed"}
    }
}'
New-item -Path "C:\Program Files (x86)\Scripts\Add-Printers\{Office Location}.ps1" -ItemType "file" -force -value $ScriptContents
}

If ($Null -eq $TaskCheck)
{
$actions = New-ScheduledTaskAction -Execute powershell.exe -Argument '-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Program Files (x86)\Scripts\Add-Printers\{Office Location}.ps1"'
$Trigger = New-ScheduledTaskTrigger -AtLogon
$Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\USERS"
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries 
$Task = New-ScheduledTask -Action $Actions -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Logon task to check if all {Office Location} printer connections have been added to the user profile."
Register-ScheduledTask "Add Printers - {Office Location}" -InputObject $Task
Start-ScheduledTask -TaskName "Add Printers - {Office Location}"
}
