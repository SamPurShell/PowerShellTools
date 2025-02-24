$PopupTitle = "CorneaGen Cloud Provisioning Tool"
$PopupMessage = "Welcome to the Cloud Provisioning tool! Please Press the OK button to run the tool, or the Cancel button to cancel. Your computer will shut down automatically when the program has finished running."
$PopupOptions = "OkCancel"
$PopupAnswer = [System.Windows.Forms.MessageBox]::Show($PopupMessage,$PopupTitle,$PopupOptions,[System.Windows.Forms.MessageBoxIcon]::Exclamation)

    if ($PopupAnswer -eq "Cancel") {
        Break
    }

#Setup logging and timestamp
$TimeStamp = Get-Date -Format "hh:mm:ss-MM-dd-yyyy"
$LogPath = "C:\logs\LogPath.log"
$LogPathTest = Test-Path -Path $LogPath
If ($LogPathTest -ne $True)
    {
    New-Item -Path $logpath -ItemType file -force | out-nui
    }
Start-Transcript $LogPath -append -InformationAction SilentlyContinue -Force | Out-Null

#Setup header for posting to Azure Queue and Teams
$TeamsHeader = @{
"API-Key" = "XXXXXXXXXXXXX" #This is the API key to post to the Teams logic app for notifications
}

$i = 0
Write-Progress -activity 'Running' -status "Validating user details..." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
#Check that program is running under PCAdmin account
$LoggedInAccount = (whoami).Split('\')[1]

If ($LoggedInAccount -notmatch 'PCAdmin')
{
$i = 0
Write-Progress -activity 'Error' -status "Looks like you are not using the PCAdmin account. Please log in with the PCAdmin account and try again. If you're unable to login with the PCAdmin account please contact the IT Help Desk." -percentComplete (($i / 100)  * 100);
write-host "Looks like you are not using the PCAdmin account. Please log in with the PCAdmin account and try again. If you're unable to login with the PCAdmin account please contact the IT Help Desk."
Start-Sleep -s 1
Exit
}
$i = 20
Write-Progress -activity 'Running' -status "Removing from domain" -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
$DomainCheck = (Get-CimInstance win32_computersystem).PartOfDomain

If ($DomainCheck -eq $False)
{
$i = 20
Write-Progress -activity 'Error' -status "This computer is not domain-joined, thus this tool does not need to be run." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
write-host "This computer is not domain-joined, thus this tool does not need to be run."
Exit
}

$Computername = $env:COMPUTERNAME.ToUpper()
#Check if they have internet access
$i = 25
Write-Progress -activity 'Running' -status "Checking network connection..." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
$CanTalkToInternet = Test-NetConnection 8.8.8.8 -InformationLevel Quiet -WarningAction SilentlyContinue
If ($CanTalkToInternet -ne $True)
{
Write-Progress -activity 'Error' -status "No internet - please confirm internet connection is working and launch the program again." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
write-host "No internet connectivity - please confirm internet connection is working and launch the program again."
Exit
}

#Disconnect from all VPN connections
$VpnCheckAllUsers = Get-VpnConnection -AllUserConnection | Where-Object { $_.ConnectionStatus -eq "Connected" }
if ($null -ne $VpnCheckAllUsers)
{
rasdial $VpnCheckAllUsers.Name /disconnect | Out-Null
}

$VPNCheck = Get-VpnConnection | Where-Object { $_.ConnectionStatus -eq "Connected" }
if ($null -ne $VpnCheck)
{
rasdial $VpnCheckAllUsers.Name /disconnect | Out-Null
}


#Check if they have line of sight to DC, and then change computer from domain to workgrou
$CantalkToDC = Test-Connection -ComputerName DC01.example.local -Quiet -Count 2
If ($CantalkToDC -eq $True)
{
$CorneaGenAdapter = @()
$DisableNICRetryCount = 0
Do {
    $i = 25
    Write-Progress -activity 'Running' -status "Getting networking interface details..." -percentComplete (($i / 100)  * 100);
    Start-Sleep -Seconds 5

    $CorneaGenAdapter += Get-NetConnectionProfile -Name example.local

    $AdapterToDisable = Get-NetAdapter -InterfaceIndex $CorneaGenAdapter.InterfaceIndex

    #Disable all network adapters with corneagen.local DNS suffix
    Disable-NetAdapter -Name $AdapterToDisable.Name -Confirm:$false
    $i = 25
    Write-Progress -activity 'Running' -status "Temporarily disabling network connection..." -percentComplete (($i / 100)  * 100);
    Start-Sleep -Seconds 15

    $CantalkToDC = Test-Connection -ComputerName DC01.example.local -Quiet -Count 2
    
    If ($CantalkToDC -eq $True)
    {
    $DisableNICRetryCount++
    }

}
Until(($CantalkToDC -eq $False) -or ($DisableNICRetryCount -eq '15'))

If ($DisableNICRetryCount -eq '15')
{

$i = 25
Write-Progress -activity 'Error.' -status "Failed to disconnect from on-premises connection, retry count exceeded. Alerting IT." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1

$TeamsNotificationJson = "{'MessageText':'$($Computername) could not lose line-of-sight to DC and exceeded retry count'}"
$TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoTeamsAPIGateway"
$TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post
write-host "system could not lose line-of-sight to DC and exceeded retry count, IT has been notified."
Exit
}
}

$i = 35
Write-Progress -activity 'Running' -status "Removing computer from domain..." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
Remove-Computer -WorkgroupName SomeWorkGroupName -ErrorVariable ErrorMessage -Force -WarningAction SilentlyContinue
$i = 35
Write-Progress -activity 'Running' -status "Removing computer from domain..." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 10

#Check if computer was removed from domain
If ((gwmi win32_computersystem).partofdomain -eq $true) 
{
$i = 35
Write-Progress -activity 'Error.' -status "Computer failed to remove from domain, checking network connection in order to alert IT." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1

#Re-enable NIC if needed to re-establish internet connection if computer wasn't removed from domain
$EnableNICRetryCount = 0 
Do{
    Enable-NetAdapter -Name $AdapterToDisable.Name
    start-sleep -Seconds 10
    $InternetTest = Test-Connection google.com -Quiet -Count 2

    If ($False -eq $InternetTest)
    {
    $EnableNICRetryCount++
    }
}
Until (($InternetTest -eq $True) -or ($EnableNICRetryCount -eq '15'))

#Show user message if NIC won't re-enable to notify IT (since Teams posting won't work)
If ($EnableNICRetryCount -eq '15')
{
$i = 20
Write-Progress -activity 'Error.' -status "Failed to re-establish internet connection, please contact IT and alert them of this error." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
Write-host "Failed to re-establish internet connection, please contact IT and alert them of this error."
Exit
}
#error handling in case undomain join fails with error
$TeamsNotificationJson = "{'MessageText':'Could not remove $($Computername) from the local domain. Error was: $($ErrorMessage)'}"
$TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoTeamsAPIGateway"
$TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post
Write-host "Computer failed to remove from domain. IT has been notified."
Exit
}

If ($Null -ne $AdapterToDisable)
{
$EnableNICRetryCount = 0 
Do{
    #Turn them all back on
    $i = 40
    Write-Progress -activity 'Running' -status "Turning network connection back on..." -percentComplete (($i / 100)  * 100);
    Start-Sleep -s 5
    Enable-NetAdapter -Name $AdapterToDisable.Name
    $CantalkToDC = Test-Connection -ComputerName DC01.example.local -Quiet -Count 2

    If ($CantalkToDC -eq $False)
    {
    $EnableNICRetryCount++
    }
}
Until (($CantalkToDC -eq $True) -or ($EnableNICRetryCount -eq '15'))

If ($EnableNICRetryCount -eq '15')
{
Write-host "Failed to re-establish network connection. Please contact the Help Desk and notify them of this error." -ForegroundColor Red
Exit

$i = 60
Write-Progress -activity 'Running' -status "Removing temporary files..." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
}
}

#there is a separate Intune deployment that adds a shortcut to this tool, so we want that removed. Also deleted the version file for SMAC so that it re-runs to reset local admin password the user is using for this program.
Remove-Item -Path "C:\Users\PCAdmin\Desktop\CloudProvision.exe" -Force -ErrorAction SilentlyContinue
Remove-item -path "C:\Program Files (x86)\SMAC\*.txt" -Force -ErrorAction SilentlyContinue

$i = 80
Write-Progress -activity 'Running' -status "Writing to online services..." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
$Computername = $Computername = $env:COMPUTERNAME.ToUpper()
$URI = "https://api.azure-api.net/api/URLPathtoStorageQueueAPIGateway"
$Header = @{
"API-Key" = "XXXXXXXXXXX" #This is the API key for the API Gateway in front of the storage queue SAS URL. This key and the backend URL should be Write/Post-only. 
}
$Body = @"
<QueueMessage>  
    <MessageText>$($Computername)</MessageText>  
</QueueMessage>
"@

$response = Invoke-RestMethod -Uri $URI -Headers $Header -Body $Body -Method Post -ErrorVariable ErrorMessage

If ($Null -eq $Response)
{
$TeamsNotificationJson = "{'MessageText':'$($Computername) could not be posted to Azure Queue from the client machine. Error was: $($ErrorMessage)'}"
$TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoTeamsAPIGateway"
$TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post
$i = 80
Write-Progress -activity 'Error' -status "Failed to post machine name to Queue storage in Azure. The Help Desk has been notified." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
Write-host "Failed to post machine name to Queue storage in Azure. The Help Desk has been notified."
Exit
}
Else
{
$TeamsNotificationJson = "{'MessageText':'$($Computername) has been syspreped and successfully added to the queue.'}"
$TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoTeamsAPIGateway"
$TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post
}
$i = 99
Write-Progress -activity 'Running' -status "Preparing to shut down..." -percentComplete (($i / 100)  * 100);
Start-Sleep -s 1
C:\windows\system32\Sysprep\sysprep.exe /shutdown /oobe
