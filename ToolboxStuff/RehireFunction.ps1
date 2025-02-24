#You will need to authenticate to various systems before running this (AzureAD Powershell, Graph Powershell, Exchange)
#When a user is disabled in our toolbox, a CSV log is created with all of their details before the tool removes them. This option allows a Helpdesk user to edit that CSV and then reactivate the user with all groups/mailboxes/licenses/teams/etc that are in that CSV. 

Function Rehire-User
{

Write-Log -LogType UserAction -LogContent "`n$($env:username) Initiated rehire user subsystem" -TimeStamp 
Write-Log -LogType UserAction -Output -LogContent "***<><>  Reactivate a Rehired User  <><>***`n"

Set-CG-Variables #This is a function that sets some basic variables in our environment, like domain name and DC.
$DisabledUsersPath = '\\FileSharePathToCSV\csv-output'
$RehireName = Read-Host "Please input the users full name"
$RehireNameFiltered = '*' + $RehireName + '.csv'
Write-Log -LogType UserAction -LogContent "Searching disabled log for $($RehireName)." -Output
$TemplateCSV = Get-ChildItem $DisabledUsersPath -Filter $RehireNameFiltered
    If ($Null -eq $TemplateCSV)
    {
        Do
        {
        Write-Log -LogType UserAction -LogContent "Could not find a disabled log for $($RehireName). Please select the rehired users CSV in the popup window..." -Output
        $TemplateCSV = Open-File-Dialog -InitialDirectory $DisabledUsersPath
        $manualfileselect = $True
        }
        Until ('' -ne $TemplateCSV)
    }
    If ($manualfileselect -eq $True)
    {
    $RehireUserCSVPath = $TemplateCSV
    }
    Else
    {
    $RehireUserCSVPath = $DisabledUsersPath + '\' + $TemplateCSV
    }

Write-Log -LogType UserAction -LogContent "Using disabled user file - $($RehireUserCSVPath)" -Output
do
{
$RehireUserCSV = import-csv $RehireUserCSVPath

$RehireUserArrayProperties = [ordered] @{
                    DisplayName = $RehireUserCSV.DisplayName | Where-Object { $_ } 
                    Domain = $RehireUserCSV.Domain | Where-Object { $_ } 
                    Title = $RehireUserCSV.Title | Where-Object { $_ } 
                    Department = $RehireUserCSV.Department | Where-Object { $_ } 
                    Manager = $RehireUserCSV.Manager | Where-Object { $_ } 
                    Company = $RehireUserCSV.Company | Where-Object { $_ } 
                    OULocation = $RehireUserCSV.OULocation | Where-Object { $_ } 
                    Mailbox = $RehireUserCSV.Mailbox | Where-Object { $_ } 
                    ADGroups = $RehireUserCSV.ADGroups | Where-Object { $_ } 
                    AADGroups = $RehireUserCSV.AADGroups | Where-Object { $_ } 
                    AADGroupsAll = $RehireUserCSV.AADGroupsAll | Where-Object { $_ } 
                    DistroLists = $RehireUserCSV.DistroLists | Where-Object { $_ } 
                    SharedMailboxes  = $RehireUserCSV.SharedMailboxes | Where-Object { $_ } 
                    SharedSendAs = $RehireUserCSV.SharedSendAs | Where-Object { $_ } 
                    Teams = $RehireUserCSV.Teams | Where-Object { $_ } 
                    TeamsOwner = $RehireUserCSV.TeamsOwner | Where-Object { $_ } 
                    Licenses = $RehireUserCSV.Licenses | Where-Object { $_ } 
                    Office = $RehireUserCSV.Office | Where-Object { $_ } 
                    Street = $RehireUserCSV.Street | Where-Object { $_ } 
                    City = $RehireUserCSV.City | Where-Object { $_ } 
                    Zip = $RehireUserCSV.Zip | Where-Object { $_ } 
                    Country = $RehireUserCSV.Country | Where-Object { $_ } 
                 }

Write-Host "`n`n**_________________Please confirm user details below_________________**`n" -ForegroundColor White

$RehireUserArrayProperties | Format-table

do
{
Write-Output "Enter 1 to confirm these user details, or 2 to open the CSV and edit them."
$RehireDetailsConfirmed = Read-Host "`nPlease make a selection"
}
until (($RehireDetailsConfirmed -eq '1') -or ($RehireDetailsConfirmed -eq '2'))

If ($RehireDetailsConfirmed -eq '2')
{
Write-host "Opening $($TemplateCSV), please save the file when you are finished making changes."
start-process -FilePath $RehireUserCSVPath
Write-host "When you have finished making changes and have saved the file, press Enter to continue."
Read-Host -Prompt "Press ENTER to continue"
}
}
until ($RehireDetailsConfirmed -eq '1')

Write-Log -LogType UserAction -LogContent "Confirmed user properties as: $($RehireUserArrayProperties)"
$EmployeeNumber = Read-host "Please input their Employee Number now"

$RehireADUserHash = @{
    Identity = $RehireUserArrayProperties.DisplayName -replace " ","."
    Title = $RehireUserArrayProperties.Title
    EmployeeNumber = $EmployeeNumber
    Department = $RehireUserArrayProperties.Department
    Company = $RehireUserArrayProperties.Company
    Office = $RehireUserArrayProperties.Office
    StreetAddress = $RehireUserArrayProperties.Street
    City = $RehireUserArrayProperties.City
    PostalCode = $RehireUserArrayProperties.Zip
    Country = $RehireUserArrayProperties.Country
    Server = $dc
    Manager = $RehireUserArrayProperties.Manager
    }

$RehireName = $RehireUserArrayProperties.DisplayName
write-host "Finding user account for $($RehireName) in AD..."

$RehireADUser = Get-ADUser -Filter {Name -eq $RehireName}

write-host "reactivating $($RehireADUser.UserPrincipalName) in AD..."

Enable-ADAccount -Identity $RehireADUser.SamAccountName

Write-host "Setting account details to the values in the CSV."

Set-ADUser @RehireADUserHash

$NewRehireADUserName = $RehireUserArrayProperties.DisplayName

$NewRehireADUser = Get-ADUser -Filter {Name -eq $NewRehireADUserName}

If ($Null -eq $NewRehireADUser)
{
write-host "Cannot find AD account for $($NewRehireADUserName). Please confirm the name/check AD and try again." -ForegroundColor Red
Read-Host -Prompt "Press Enter to return to the main menu" | Out-Null
. ("\\corneagen.local\shares\IT\Scripts\Git-Repo\Infrastructure-Tools\CGToolbox\Menus\MainMenu.ps1")
}

write-host "Adding AD Groups..."

foreach ($ADGroup in $RehireUserArrayProperties.ADGroups)
{
    Add-ADGroupMember -Identity $ADGroup -Members $NewRehireADUser -Server $dc
}

write-host "Changing primary group for user..."
$DomainUsersGroup = Get-ADGroup -Identity "Domain Users" -properties @("primaryGroupToken")
Set-ADUser -Identity $NewRehireADUser -Replace @{PrimaryGroupID=$DomainUsersGroup.primaryGroupToken} -server $dc
Start-Sleep -Seconds 30
write-host "Removing $($NewRehireADUser.Name) from Disabled Users group..."
Remove-ADGroupMember -Identity 'DisabledUsersADGroup' -Members $NewRehireADUser -Server $dc -Confirm:$false
 
write-host "Moving OU of $($RehireUserArrayProperties.DisplayName)..."

Move-ADObject -Identity $NewRehireADUser -TargetPath $RehireUserArrayProperties.OULocation

write-host "resetting users password to default password..."

Set-ADAccountPassword -Identity $NewRehireADUser.SamAccountName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "WhateverDefaultPasswordYouWant" -Force)

Set-ADUser -Identity $NewRehireADUser.SamAccountName -ChangePasswordAtLogon $true

write-host "unhiding user mailbox..."

Get-Automation-Creds -ExchangeOnPrem

$UPN = $NewRehireADUser.UserPrincipalName

Invoke-Command -Session $OnPremExchangeSession -ScriptBlock {Set-RemoteMailbox $using:upn -HiddenFromAddressListsEnabled $False} -AsJob -ErrorAction SilentlyContinue -ErrorVariable jobError

write-host "Applying licenses..."

$NewLicensingArray = $RehireUserArrayProperties.Licenses -replace 'ENTERPRISEPACK', 'E3' -replace 'MCOTEAMS_ESSENTIALS', 'TeamsPhone' -replace 'O365_BUSINESS_ESSENTIALS', 'Basic'
Foreach ($License in $NewLicensingArray | where ({($_ -like "E3") -or ($_ -like "EMS") -or ($_ -like "Basic")}))
{
    Add-UserLicenses -LicenseType $License -Domain $script:Domain -UPN $NewRehireADUser.UserPrincipalName
}

write-host "Adding AAD Groups..."
$AzureADUser = Get-AzureADUser -Filter "userPrincipalName eq '$upn'"
foreach ($AADGroup in $RehireUserArrayProperties.AADGroups)
{
    $AADGroupObject = Get-AzureADGroup -SearchString $AADGroup
    
    Add-AzureADGroupMember -ObjectId $AADGroupObject.ObjectId -RefObjectId $AzureADUser.ObjectId
}

Write-host "Converting Shared mailbox to a user mailbox..."

Get-Automation-Creds -ExchangeOnline

Set-Mailbox -Identity $upn -Type Regular


Write-host "Adding Distribution Groups..."

foreach ($DL in $RehireUserArrayProperties.DistroLists)
    {

       $DLFound = Get-DistributionGroup -Identity $DL -ErrorAction silentlycontinue
       Add-DistributionGroupMember -Identity $DLFound.identity -Member $upn
    }

Write-host "Adding Shared Mailboxes"
    foreach ($Mailbox in $RehireUserArrayProperties.SharedMailboxes)
    {
        $MailboxFound = Get-Mailbox -Identity $Mailbox -ErrorAction silentlycontinue
    }
        Add-MailboxPermission -Identity $MailboxFound.Name -User $upn -AccessRights FullAccess -InheritanceType All

write-host "Adding Send As Permissions"
    foreach ($Mailbox in $RehireUserArrayProperties.SharedSendAs)
    {
        $MailboxFound = Get-Mailbox -Identity $Mailbox -ErrorAction silentlycontinue 
        
        Add-RecipientPermission -Identity $MailboxFound.identity -Trustee $upn -AccessRights "SendAs" -Confirm:$false

    }

Write-host "DONE!" -foregroundcolor Green

}
