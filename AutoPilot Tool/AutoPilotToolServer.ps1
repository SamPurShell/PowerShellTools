#This script reads each computer name in the the Azure Storage Queue (which is posted as the last step of the client script) and deletes computer objects with that name from AD/AAD/Intune. It then assigns the AutoPilot AAD device for the computer (which is just the serial number) to the appropriate deployment profile based on the computer name that was captured.

#Start logging and set variables
$script:timeStamp = Get-Date -Format 'hh:mm:ss-MM-dd-yyyy'
Start-Transcript 'C:\Logs\AutoPilotTool - Server.log' -append -Force
Write-Output "$($timeStamp) Run Started!"

#Initialize headers for Teams channel POST and Azure Storage Queue GET
$Header = @{
"API-Key" = "xxxxxxxxxxxxxx" #Storage Queue GET API key
} 

$TeamsHeader = @{
"API-Key" = "xxxxxxxxxxxxxx" #Teams logic app POST API key.
} 

$response = Invoke-RestMethod -Uri "https://api.azure-api.net/api/URLPathtoStorageQueueAPIGateway" -Headers $Header -Method Get 

# Output the response content (XML)
$response = $response.Replace("ï»¿","")

$response = [xml]$response

write-host "$($response.QueueMessagesList.QueueMessage.Count) messages are currently in the queue."

#for each message (computer) in the queue, do the things
foreach ($message in $response.QueueMessagesList.QueueMessage)
{
    Write-Output "We got messageID $($message.MessageId) that says $($message.MessageText)"
    $Computer = $message.MessageText
    $InTuneDevice = Get-mgdeviceManagementManagedDevice -Filter "Devicename eq '$($computer)'"
    $InTuneDevice = $InTuneDevice | Where-Object {$_.AzureAdRegistered -EQ 'True'}

    
    If (($Null -eq $IntuneDevice) -or ($IntuneDevice.count -gt '1'))
    {
    $TeamsNotificationJson = "{'MessageText':'Could not find $($Computer) in Intune. Please investigate.'}"
    $TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoTeamsAPIGateway"
    $TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post
    #Delete the message from queue
    $messageRequest = "https://api.azure-api.net/api/URLPathtoStorageQueueAPIGateway" + $message.MessageId + "+" + $message.PopReceipt
    $DeleteMessage = Invoke-RestMethod -Uri $messageRequest -Headers $Header -Method Delete 
    stop-transcript
    exit
    }
    Else
    {
    write-host "Removing $($computer) from Active Directory..." -ForegroundColor Yellow
    Get-ADComputer -Identity $computer | Remove-ADobject -recursive -Confirm:$False
    "Deleting $($InTuneDevice.DeviceName) from Intune now..."
        Remove-MgDeviceManagementManagedDevice -manageddeviceID $InTuneDevice.ID
        Start-Sleep -Seconds 15
        $ConfirmIntuneDeletion = Get-mgdeviceManagementManagedDevice -Filter "Devicename eq '$($computer)'"
        If ($null -ne $ConfirmIntuneDeletion)
            {
            Do
            {
            write-host "Looks like the computer hasn't been removed from Intune yet. This tool will wait 2 minutes and then check again..." -ForegroundColor Yellow
            $ConfirmIntuneDeletionCount++
            Start-Sleep -Seconds 120
            $ConfirmIntuneDeletion = Get-mgdeviceManagementManagedDevice -Filter "Devicename eq '$($computer)'"
            }
            Until (($null -eq $ConfirmIntuneDeletion) -or ($ConfirmIntuneDeletionCount -eq '7'))
            }
            If ($null -eq $ConfirmIntuneDeletion)
            {
            Write-host "Computer was successfully removed from Intune!" -ForegroundColor Green
            $ConfirmIntuneDeletionCount = '0'
            }
            If ($ConfirmIntuneDeletionCount -eq '7')
            {
            $TeamsNotificationJson = "{'MessageText':'Could not remove $($Computer) from Intune, retry count of 7 was exceeded. Please investigate.'}"
            $TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoStorageQueueAPIGateway"
            $TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post
            #Delete the message from queue
            $messageRequest = "https://cg-toolbox-api.azure-api.net/api/autopilot/queue/" + $message.MessageId + "+" + $message.PopReceipt
            $DeleteMessage = Invoke-RestMethod -Uri $messageRequest -Headers $Header -Method Delete 
            stop-transcript
            exit
            }
            }
        write-host "Searching for AutoPilot device with serial number $($IntuneDevice.SerialNumber) in Azure AD..."
        $AADdevice = Get-MgDevice -Filter "displayName eq '$($IntuneDevice.SerialNumber)'" -CountVariable CountVar -ConsistencyLevel eventual
        If ($Null -eq $AADdevice)
        {
        $TeamsNotificationJson = "{'MessageText':'Could not find an object for $($IntuneDevice.SerialNumber) in Azure AD. Please investigate.'}"
        $TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoTeamsAPIGateway"
        $TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post
        #Delete the message from queue
        $messageRequest = "https://api.azure-api.net/api/URLPathtoStorageQueueAPIGateway" + $message.MessageId + "+" + $message.PopReceipt
        $DeleteMessage = Invoke-RestMethod -Uri $messageRequest -Headers $Header -Method Delete 
        stop-transcript
        exit
        }
        If ($Computer.startswith("D-") -eq $True) #whatever identifier you have in the computer name for desktop computers
        {
        $DeviceType = '1'
        }

        If ($Computer.startswith("L-") -eq $True) #whatever identifier you have in the computer name for laptop computers
        {
        $DeviceType = '2'
        }

        If ($DeviceType -eq '1')
        {
        write-host "Adding AutoPilot object for $($AADdevice.DisplayName) to the deployment profile for Desktops..."
        $DesktopGroup = Get-MgGroup -Filter "DisplayName eq 'GroupNameForAutoPilotDesktopDeploymentProfile'"  -CountVariable CountVar -ConsistencyLevel eventual
        New-MgGroupMember -GroupId $DesktopGroup.Id -DirectoryObjectId $AADdevice.id -ErrorAction Stop
        write-host "Successfully assigned $($AADdevice.DisplayName) to AutoPilot Desktop Deployment profile!" -ForegroundColor Green
        }

        If ($DeviceType -eq '2')
        { 
        write-host "Adding $($AADdevice.DisplayName) to AutoPilot deployment profile for Laptops..."
        $LaptopGroup = Get-MgGroup -Filter "DisplayName eq 'GroupNameForAutoPilotLaptopDeploymentProfile'"  -CountVariable CountVar -ConsistencyLevel eventual
        New-MgGroupMember -GroupId $LaptopGroup.Id -DirectoryObjectId $AADdevice.id -ErrorAction Stop
        write-host "Successfully assigned $($AADdevice.DisplayName) to AutoPilot Laptop Deployment profile!" -ForegroundColor Green
        }

        #Delete the message from queue
        $messageRequest = "https://api.azure-api.net/api/URLPathtoStorageQueueAPIGateway" + $message.MessageId + "+" + $message.PopReceipt
        $DeleteMessage = Invoke-RestMethod -Uri $messageRequest -Headers $Header -Method Delete

        #Send completed post to Teams logic app
        $TeamsNotificationJson = "{'MessageText':'$($Computer) has been processed successfully and removed from the queue. Please wait for the profile status to change to Assigned for $($AADdevice.DisplayName) at this link - https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/AutopilotDevices.ReactView/filterOnManualRemediationRequired~/false'}"
        $TeamsNotificationURI = "https://api.azure-api.net/api/URLPathtoTeamsAPIGateway"
        $TeamsNotificationResponse = Invoke-RestMethod -Uri $TeamsNotificationURI -Headers $TeamsHeader -Body $TeamsNotificationJson -Method Post           
}
Write-Output "Run completed at $($timeStamp)"
stop-transcript   
