#This function is used to update an existing users name in all the places (AD/ADD/Exchange). It is also used to convert a contract worker to full-time. 

function Run-NameChange {
    Param(
        [string]
        $username,
        [ValidateSet("example.com","example.org")]
        $Domain = $domain
)
#Start Log, set variables and creds, and start the user account lookup function         
Write-Log -LogType UserAction -LogContent "`n$($env:username) Initiated Convert Contract Worker to Regular User subsystem" -TimeStamp 
Write-Log -LogType UserAction -Output -LogContent "***<><>  Convert Contract Worker to Regular User  <><>***`n" 

Set-CG-Variables

Get-Automation-Creds -ExchangeOnPrem
 
Get-UserAccount 

do
{
Write-Output "Are you converting a contract worker to regular employee?"
Write-Host "     1: Yes"
Write-Host "     2: No"
$ModeInput = Read-Host "`nPlease make a selection"
}
until (($Modeinput -eq '1') -or ($Modeinput -eq '2'))

If ($Modeinput -eq '1')
{
Write-Log -LogType UserAction -Output -LogContent "Starting contract worker conversion process for $($Aduser.UserPrincipalName)" -timestamp
Read-Host -Prompt "Press ENTER to continue"

Write-Log -LogType UserAction -Output -LogContent "Removing $($Aduser.UserPrincipalName) from the CONTRACT group..." -timestamp
Remove-ADGroupMember -Identity CONTRACTOR_GROUP $ADUser -Server $DC -Confirm:$false

#Input menu to identify which type of employee the contract worker will become 
do
{
Write-Output "Will this user be a salaried or hourly employee?"
Write-Host "     1: Salaried"
Write-Host "     2: Hourly"
$input = Read-Host "`nPlease make a selection"
}
until (($input -eq '1') -or ($input -eq '2'))

If ($input -eq '1')
{
Write-Log -LogType UserAction -Output -LogContent "SALARIED was selected, adding $($Aduser.UserPrincipalName) to the FTE_Salaried Group..." -TimeStamp
Add-ADGroupMember -Identity EXEMPT $ADUser -Server $DC
}

If ($input -eq '2')
{
Write-Log -LogType UserAction -Output -LogContent "HOURLY was selected, adding $($Aduser.UserPrincipalName) to the FTE_Hourly Group..." -TimeStamp
Add-ADGroupMember -Identity NONEXEMPT $ADUser -Server $DC
}

#Split the users last name with -cw in it (surname) into an array at the dash, delete CW part from the array, convert variable from array to string
$NewSurname = $ADuser.Surname.split('-')
$NewSurname = @($NewSurname | Where-Object { $_ -ne "CW" })
$NewSurname = $($NewSurname)

#set name variables that will be changed in AD
$NewSAMAccountName = $($ADUser.GivenName) + "." + $($NewSurname)
$NewUPN = $NewSAMAccountName + "@" + $($Domain)
$NewDisplayName = $($ADUser.GivenName) + " " + $($NewSurname)

}

If ($Modeinput -eq '2')
{
Write-Log -LogType UserAction -Output -LogContent "Starting user renaming process for $($Aduser.UserPrincipalName)" -timestamp
Read-Host -Prompt "Press ENTER to continue"

Write-Output "Please enter the NEW first and last name for $($Aduser.UserPrincipalName)"
$NewFirstName = Read-host -Prompt "First name"
$NewSurname = Read-host -Prompt "Last name"
$NewSAMAccountName = $($NewFirstName) + "." + $($NewSurname)
$NewUPN = $NewSAMAccountName + "@" + $("$Domain")
$NewDisplayName = $($NewFirstName) + " " + $($NewSurname)
}

#Perform the AD changes
  
Write-Log -LogType UserAction -Output -LogContent "Updating the users account name in all places..." -TimeStamp
Set-ADUser $aduser.SamAccountName -replace @{
                                            mailNickName=$($NewSAMAccountName);
                                            UserPrincipalName=$($NewUPN);
                                            sn=$($NewSurname);
                                            DisplayName=$($NewDisplayName);
                                            SAMAccountName=$($NewSAMAccountName)
                                            } -Server $DC
Rename-ADObject -Identity $aduser -NewName $($NewDisplayName)

Write-host "Waiting for the changes to replicate..."

#this pause is to wait for the AD changes to sync with Exchange on-prem 
Output-Wait-Dots 
$TotalCount = 15

#Now that changes have sync'd, flip email address policy off and then back on to trigger Exchange policy enforcement on the new changes
Write-Log -LogType UserAction -Output -LogContent "Now updating $($NewDisplayName)'s Exchange mailbox..." -TimeStamp
Invoke-Command -Session $OnPremExchangeSession -ScriptBlock {Set-RemoteMailbox $using:NewDisplayName -EmailAddressPolicyEnabled $false} -AsJob -ErrorAction SilentlyContinue -ErrorVariable jobError

Output-Wait-Dots
$TotalCount = 5

Invoke-Command -Session $OnPremExchangeSession -ScriptBlock {Set-RemoteMailbox $using:NewDisplayName -EmailAddressPolicyEnabled $true} -AsJob -ErrorAction SilentlyContinue -ErrorVariable jobError

#waiting here for the email address policy to create their new mail.onmicrosoft.com SMTP address before assigning it as the remote routing address. 
Output-Wait-Dots

$RemoteRoutingAddress = $($NewSAMAccountName) + "mail.onmicrosoft.com"

Invoke-Command -Session $OnPremExchangeSession -ScriptBlock {Set-RemoteMailbox $using:Newdisplayname -RemoteRoutingAddress $using:RemoteRoutingAddress} -AsJob -ErrorAction SilentlyContinue -ErrorVariable jobError

If ($ModeInput -eq '1')
{
Get-Automation-Creds -ExchangeOnline
Test-OnlineConnection -ExchangeOnline 
Write-Log -LogType UserAction -Output -LogContent "Connected to Exchange Online, adding $($NewDisplayName) to the _AllStaff Distibution group..." -TimeStamp
Add-DistributionGroupMember -Identity "_All Staff" -Member $($NewUPN)
}

Write-Log -LogType UserAction -Output -LogContent "DONE!" -TimeStamp
}