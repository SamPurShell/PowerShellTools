#This is the client script which is used to cycle random passwords for a local administrator account every 30 days 

#Check/create local path to store log and version files
$Script:ShortcutPath = "C:\Program Files (x86)\TechServices\Scripts\SMAC\RetryFile.exe"
$Script:SourceFilePath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
Copy-Item $SourceFilePath -Destination $ShortcutPath -PassThru

Function Get-LocalPath
{
$LocalSMACPath = Test-Path -Path 'C:\Program Files (x86)\TechServices\Scripts\SMAC'

If ($LocalSMACPath -eq $false)
    { 
    New-Item -Path 'C:\Program Files (x86)\TechServices\Scripts\SMAC' -ItemType Directory
    }
}

Function Start-LocalLog
{
$script:timeStamp = Get-Date -Format 'hh:mm:ss-MM-dd-yyyy'
$LogPathTest = Test-Path -Path 'C:\Logs\SMAC-Client.log'
If ($LogPathTest -ne $True)
    {
    New-Item -Path 'C:\Logs\SMAC-Client.log' -ItemType file
    }
Start-Transcript 'C:\Logs\SMAC-Client.log' -append -Force
Write-Output "$($timeStamp) Run Started!"
}

#Generate passwords.
Function Generate-Password-Dice
{
[CmdletBinding()]
param (
    [Parameter()]
    [Int]
    $Iterations = 0,
    [switch]
    $MoarComplexity
)
$Dice = Import-Csv -Path "C:\Program Files (x86)\TechServices\Scripts\SMAC\DICEList.csv" #DiceList of possible password phrases, there are plenty of good ones available.
If ($Iterations -eq 0)
{
    $RandomIteration = Get-Random -Maximum 8 -Minimum 2
    $Iterations = $RandomIteration
}

#Generate some random data and populate the variables to be used later
$Iteration = 0
$Password = ""
$rndNum = Get-Random -Maximum 99 -Minimum 1
$rndSymbol = Get-Random -InputObject "!","@","#","$","%","^","&","*","(",")","=","+","<",">","/","\"

$Script:PasswordOutput = $($Password)
Write-Output "Password was generated at $($timeStamp)."
}

Function Identify-AdminAccount
{
    $Machine = $env:COMPUTERNAME
    $userName = 'PCAdmin'
    $password = ConvertTo-SecureString -String 'TempPasswordWhateverYouWantItToBe' -AsPlainText -Force
    $AdminGroup = 'Administrators'
    $Script:AdminAccount = Get-CimInstance -ClassName Win32_GroupUser | where {($_.GroupComponent.name -like $AdminGroup) -and ($_.PartComponent.Name -like $userName)}

    if ($AdminAccount -eq $null)
    {
    Try{
    New-LocalUser -name $userName -Password $password -Description "admin account managed by the SMAC tool." -AccountNeverExpires  -PasswordNeverExpires
    Add-LocalGroupMember -Group $AdminGroup -Member $userName
    $Script:AdminAccount = Get-CimInstance -ClassName Win32_GroupUser | where {($_.GroupComponent.name -like $AdminGroup) -and ($_.PartComponent.Name -like $userName)} -ErrorVariable ErrorMessage
    Write-Output "The following account was created at $($timeStamp):" 
    $adminaccount | select-object -property GroupComponent,PartComponent |format-list
    }
    Catch {
    Write-Output "Looks like there was a problem identifying the admin account, registering error online and exiting..."
    Register-Errors -online -ErrorMessage $ErrorMessage.message -HostName $Machine
    Exit
    }
    }
    if ($null -ne $AdminAccount)
    {
    Write-Output "The following account was identified, moving on." 
    $adminaccount | select-object -property GroupComponent,PartComponent | format-list
    }
}

Function Get-PasswordVersionToWrite
{
$filename = Get-ChildItem 'C:\Program Files (x86)\TechServices\Scripts\SMAC\*.run'

switch ($filename.name)
{
    '1.run'{Write-Host "Version 1 was the last active password, so this newly generated password will be Version 2"
            Rename-Item $filename -NewName "2.run"
            $Script:ValidVersion = "2"
            $script:Password2 = $passwordoutput
            }
    '2.run' {Write-Host "Version 2 was the last active password, so this newly generated password will be Version 1"
            Rename-Item $filename -NewName "1.run"
            $Script:ValidVersion = "1"
            $script:Password1 = $passwordoutput
            }
    Default {Write-Host "No previous .run files found, so this newly generated password will be Version 1" 
            New-Item -Path 'C:\Program Files (x86)\TechServices\Scripts\SMAC\' -Name "1.run"
            $Script:ValidVersion = "1"
            $script:Password1 = $passwordoutput
            }
}
}

Write-Output "The active password version is $($runVersion)"

Function Get-ClientData
{

    #Get hostname.
    $script:Hostname = $env:COMPUTERNAME.ToUpper();

    #Write out to the log file.
    #Write-Log -File $LogFile -Status Information -Text ("Hostname: " + $Hostname);

    #Get serial number.
    $SerialNumber = (Get-WmiObject win32_bios).SerialNumber;

    #Write out to the log file.
    #Write-Log -File $LogFile -Status Information -Text ("SerialNumber: " + $SerialNumber);

    #Get machine guid.
    $MachineGuid = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid;

    #Get Date for last password update.
    $LastUpdate = Get-Date -Format 'hh:mm:ss-MM-dd-yyyy'

    #Write out to the log file.
    #Write-Log -File $LogFile -Status Information -Text ("MachineGuid: " + $MachineGuid);

    #Get public IP.
    $PublicIP = ((Invoke-RestMethod "http://ipinfo.io/json").IP);

    #Write out to the log file.
    #Write-Log -File $LogFile -Status Information -Text ("PublicIP: " + $PublicIP);

    $Sid = Get-ciminstance -Class win32_userAccount | where {($_.name -like $adminaccount.partcomponent.name) -and ($_.domain -like $adminaccount.partcomponent.domain)}
     
    #Create a new object.
    $Script:AccountObject = New-Object -TypeName PSObject;

    #Add value to the object.
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "MachineGuid@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "MachineGuid" -Value ($MachineGuid).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "LastUpdate@data.type" -value "Edm.DateTime"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "LastUpdate" -value ($LastUpdate) 
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SerialNumber@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SerialNumber" -Value ($SerialNumber).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Hostname@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Hostname" -Value ($Hostname).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Account@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Account" -Value ($AdminAccount.PartComponent.Name).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SID@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "SID" -Value ($SID.SID).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PublicIP@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PublicIP" -Value ($PublicIP).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PartitionKey@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "PartitionKey" -Value ("partition1").ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "RowKey@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "RowKey" -Value ($Hostname).ToString();
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "IsValid@data.type" -Value "Edm.Int32"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "IsValid" -Value ($ValidVersion);
    If ($password2 -eq $null)
    {
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password1@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password1" -Value ($Password1).ToString();
    }
    If ($password1 -eq $null)
    {
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password2@data.type" -Value "Edm.String"
    Add-Member -InputObject $AccountObject -Membertype NoteProperty -Name "Password2" -Value ($Password2).ToString();
    }
    Write-Output "Payload data has been set"
}

Function Test-InternetConnection
{

$Script:ConnectionTest = Test-NetConnection google.com -port 443 -WarningAction SilentlyContinue

    If ($ConnectionTest.TcpTestSucceeded -ne $True)
    {
    Write-Output "Internet connectivity test failed at $($timeStamp). Will try again in 3 hours."
    Register-Errors -retry
    }

    If ($ConnectionTest.TcpTestSucceeded -eq $True)
    {
    Write-Output "Internet connectivity test succeeded, moving on."
    }
}

Function Write-DataOnline
{
#Write the things to the table

#Upserting
If ($ConnectionTest.TcpTestSucceeded -eq $True)
{
$URI = "https://azure-api.net/api/SMAC/" + $($hostname) #Whatever you set up your URI to for API Gateway in front of your SAS key. SAS key should be write only.
$headers = @{
    "Accept" = "application/json;odata=nometadata"
    "API-Key" = "XXXXXXXXXXXXXXXXXXXXX" #There should be a When statement in Inbound processing rules to require this specific API subscription key to perform PATCH operations on the API.  
    }
$json = ConvertTo-Json -InputObject $accountobject
$ResponseCode = Invoke-webrequest $uri -Method Patch -ContentType 'application/json' -Headers $headers -Body $json -UseBasicParsing -ErrorVariable ErrorMessage
    If ($ResponseCode.StatusCode -ne "204")
    {
    $Script:ErrorMessage = $ErrorMessage
    Register-Errors -Online -retry -ErrorMessage $ErrorMessage.message -ShortcutPath $ShortcutPath -HostName $HostName
    $Script:ChangeLocalPassword = $False
    }
    If ($ResponseCode.StatusCode -eq "204")
    {
    $Script:ChangeLocalPassword = $True
    }
}
}
Function Change-LocalPassword
{
If ($ChangeLocalPassword -eq $True)
{
$SecureStringPassword = ConvertTo-SecureString -String $($passwordoutput) -AsPlainText -Force
Set-LocalUser -name $AdminAccount.PartComponent.Name -Password $SecureStringPassword
Write-Output "Password was successfully changed at $($timestamp)."
Stop-Transcript
}
}
Function Register-Errors
{
    Param(
        [switch]
        $Online,
        [switch]
        $retry,
        [string]
        $LastUpdate,
        [string]
        $ErrorMessage,
        [string]
        $URI,
        [string]
        $HostName
        )  

If ($retry -eq $True)
{
Remove-Item -path $ShortcutPath -Force
}


If ($online -eq $True)
{

$LastUpdate = Get-Date -Format 'hh:mm:ss-MM-dd-yyyy'

$Script:ErrorObject = New-Object -TypeName PSObject;
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "PartitionKey@data.type" -Value "Edm.String"
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "PartitionKey" -Value ("partition1").ToString();
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "RowKey@data.type" -Value "Edm.String"
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "RowKey" -Value ($Hostname).ToString();
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "LastUpdate@data.type" -value "Edm.DateTime"
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "LastUpdate" -value ($LastUpdate) 
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "ErrorMessage@data.type" -Value "Edm.String"
Add-Member -InputObject $ErrorObject -Membertype NoteProperty -Name "ErrorMessage" -Value ($ErrorMessage)

$headers = @{
Accept = "application/json;odata=nometadata"
  }
$ErrorJSON = ConvertTo-Json -InputObject $ErrorObject

    $uri =  {URI for separate Azure table to write errors}
    Invoke-webrequest $uri -Method merge -ContentType 'application/json' -Headers $headers -Body $ErrorJSON -UseBasicParsing
    
}
}

Get-LocalPath
Start-LocalLog
Generate-Password-Dice
Identify-AdminAccount
Get-PasswordVersionToWrite
Get-ClientData
Test-InternetConnection
Write-DataOnline
Change-LocalPassword