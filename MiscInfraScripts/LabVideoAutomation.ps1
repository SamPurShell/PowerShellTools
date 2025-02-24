#This script was written to automate video compression and storage for nightly videos recorded on lab microscopes, which was required for compliance purposes. It is recommended to use DFSR at each site to avoid high file transfer times. 
#Labs use recorders that host their own FTP server as well as regular Windows computers on the network, so this script has options for both modes

#You will need to create a config file in CSV format that includes the following in each row for each job that runs:
  # LocalPath - path to DFSR partition on the server this is running on
  # RemotePath - path on the remote computer where the raw videos are recorded/stored
  # AdditionalRemotePath - optional, for using two paths or two SD cards
  # Destination - DFS Namespace where the compressed videos are published at the end
  # FTPMode - Boolean value whether to use the WinSCP Powershell commands to use on FTP 
  # FTPHostName - Only required if FTPMode is True 

#import config file and populate variables
$RunningConfig = import-csv -path "\\PathToConfigFile\Config.csv"
ForEach ($run in $RunningConfig)
{
$LocalPath = $run.LocalPath

$RemotePath = $rfun.RemotePath

$AdditionalRemotePath = $run.AdditionalRemotePath

$Destination = $run.Destination

$FTPHostName = $run.FTPHostName

$FTPMode = $run.FTPMode

$FTPMode = [System.Convert]::ToBoolean($run.FTPMode)

#Generate the time stamps for logging purposes
$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString() + ".log"
$timeStamp = Get-Date -Format 'hh:mm:ss-MM-dd-yyyy'

#Begin logging to the folder
Start-Transcript ("C:\Logs\Lab Video Automation\LabVideoAutomation - " + $LogDate) -append -Force
Write-Output "$($timeStamp) Run Started!"

#Test if required folders exist on server and client
$ServerFolderExistsTest = Test-Path $LocalPath
$ClientFolderExistsTest = Test-path $RemotePath
$DestinationFolderExistsTest = Test-path $Destination


If ($ServerFolderExistsTest -eq $False)
{
New-Item $LocalPath -ItemType Directory
}

If ($ClientFolderExistsTest -eq $False)
{
New-Item $Remotepath -ItemType Directory
}

If ($DestinationFolderExistsTest -eq $False)
{
New-Item $Destination -ItemType Directory
}

#Test if remote path is reachable, used to send an email in separate function
$PathExistsTest = Test-path $RemotePath

##Load "CG Email" function if test fails
If ($PathExistsTest -eq $False)
{  

#Convert $localpath to array with splitting to get device name for email
$LocalPathArray = $LocalPath.split("/")
$DeviceNetBIOS = $LocalPathArray[2]

#Create the email message body HTML
$message="<b> <font color=red> <h1 style=font-size:200%> ALERT!!! </font> </h1> </mark></b> Device $($DeviceNetBIOS) was unreachable at $($timestamp). The nightly video compression job failed on this device as a result. Please check that the computer/device is online. </mark></b><br /><br /> Thank you! </mark></b><br /><br /><b>Technology Services </b><br />CorneaGen <br />"

#Send the email
#Optional - you can put details of sending an email from domain to a recipient here if you would like
}

# Import installed module WinSCP (uses WMF5)
If ($FTPMode -eq $True)
{
Import-Module WinSCP
}

# Define variables for FTP session
If ($FTPMode -eq $True)
{
$username = "UsernameToRecordersFTPServer"                                                                                             
$password = ConvertTo-SecureString "PasswordToRecordersFTPServer" -AsPlainText -Force                                                   
$credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password 
$sessionOption = New-WinSCPSessionOption -HostName $FTPHostName -Protocol sFTP -Credential $credential
}

# Start the session
If ($FTPMode -eq $True)
{
New-WinSCPSession -SessionOption $sessionOption
}
#Move .mp4 files on the recorder to a local directory
If ($FTPMode -eq $True)
{
$FormattedFilter = ("*." + $Filter)
$RemotePathWithFilter = $($RemotePath) + "/" + $($FormattedFilter)
If ($AdditionalRemotePath -ne '')
{
$RemotePathWithFilter = (($RemotePath) + "/" + ($FormattedFilter)), (($AdditionalRemotePath) + "/"  + ($FormattedFilter))
}
Receive-WinSCPItem -RemotePath $RemotePathWithFilter -LocalPath $LocalPath
}
If ($FTPMode -eq $False)
{
Copy-Item -Path $(($RemotePath) + "/*")  -Destination $LocalPath
}
#Set up Variables 
$LocalFiles = get-childitem  -Path $LocalPath -Include *.* -Recurse 
If (($FTPMode -eq $True) -and ($AdditionalRemotePath -ne ''))
{
$RemoteFiles = Get-WinSCPChildItem -path $RemotePath, $AdditionalRemotePath -filter $FormattedFilter
}
If (($FTPMode -eq $True) -and ($AdditionalRemotePath -eq ''))
{
$RemoteFiles = Get-WinSCPChildItem -path $RemotePath -Filter $FormattedFilter
}  
If (($FTPMode -eq $False) -and ($AdditionalRemotePath -ne ''))
{
$RemoteFiles = Get-ChildItem -path $RemotePath, $AdditionalRemotePath
}    
If (($FTPMode -eq $False) -and ($AdditionalRemotePath -eq ''))   
{
$RemoteFiles = Get-ChildItem -path $RemotePath
}
 
#Check Local Files and Remote Files and delete files that exist in both places from the recorder.

ForEach ($LocalFile in $LocalFiles)
{
    ForEach ($RemoteFile in $RemoteFiles)
    {
        if (($LocalFile.name -match $RemoteFile.name) -and ($LocalFile.length -match $RemoteFile.Length))
        {
            Write-Output "$($timeStamp) $($RemoteFile.FullName) was transferred to server, deleting it from the remote directory."
            If ($FTPMode -eq $True)
            {
            Remove-WinSCPItem $RemoteFile.FullName -Confirm:$False
            }
            If ($FTPMode -eq $False)
            {
            Remove-Item $RemoteFile.FullName -Confirm:$False
            }
            }
            }
            }
            
#Use Handbrake CLI to save new compressed file and delete the old file
Write-Output "$($timeStamp) Starting video compression jobs..."
$filelist = $localfiles 

$date = (Get-Date -Format 'MM-dd-yyyy')
 
$num = $filelist | measure
$filecount = $num.count
 
$i = 0;
ForEach ($file in $filelist)
{
    $i++;
    $oldfile = $file.DirectoryName + "\" + $file.BaseName + $file.Extension;
    $newfile = $file.DirectoryName + "\" + $file.BaseName + " Compressed Video - " + $date + $file.Extension;
 
    Write-Host -------------------------------------------------------------------------------
    Write-Host Handbrake Batch Encoding
    Write-Host "Processing - $oldfile"
    Write-Host "File $i of $filecount..."
    Write-Host -------------------------------------------------------------------------------
     
    Start-Process "C:\HandBrake CLI\HandBrakeCLI.exe" -ArgumentList "-i `"$oldfile`" -t 1 --angle 1 -c 1 -o `"$newfile`" -f mp4  -O  --decomb --modulus 16 -e x264 -q 20 --vfr -a 1 -6 dpl2 -R Auto -D 0 --gain 0 --verbose=0" -Wait -NoNewWindow
    Remove-Item $oldfile -confirm:$False
    Write-Output "$($timeStamp) Created new compressed file $($newfile), removed $($oldfile)"
}
Write-Output "$($timeStamp) Video compression finshed!"

#Move compressed files to destination on File Server
$LocalFiles = get-childitem  -Path $LocalPath -Recurse
ForEach ($LocalFile in $LocalFiles)
    {
    $LocalFile | Move-Item -Destination $Destination
    Write-Output "$($timeStamp) Moved $($LocalFile.FullName) to $($Destination)"
    }

#Stop Logging
Write-Output "$($timeStamp) Run Completed!"
Stop-Transcript
}
