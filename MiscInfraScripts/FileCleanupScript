#Function used to clean up various old files. Specify path, filetypes, and timeframe. 

Function Remove-OldFiles
{
Param(
    [parameter(Mandatory=$true)]
    [String]
    $Path,
    [parameter(Mandatory=$true)]
    [Int]
    $Timeframe,
    [parameter(Mandatory=$true)]
    [String]
    $Filetypes = ('logs','videos'),
    [switch]
    $TestMode
    )

#Generate the time stamps for logging purposes
$date = (Get-Date -Format 'MM-dd-yyyy').ToString() + ".log"
$timeStamp = Get-Date -Format 'hh:mm:ss-MM-dd-yyyy'
$limit = (get-date).AddDays(-$Timeframe)

#Begin logging to the folder
Start-Transcript ("C:\Logs\Remove-OldFiles\FileCleanupScript - " + $date) -append -Force

If ($filetypes -eq 'Videos')
{
    $extensions = '*.mkv', '*.mp4', '*.m4v'
}

If ($Filetypes -eq 'logs')
{
    $extensions = '*.log'
}

#Begin the run
Write-Output "$($timeStamp) Beginning Run"

    #Get the list of files for logging purposes    

    $files = Get-ChildItem -Path $path -include $extensions -Attributes !Directory -recurse -Force | Where-Object { $_.CreationTime -lt $limit } 

    #Output some friendly info for logging
    Write-Output "Located $($files.Count) files to delete"
    Write-Output "Files to delete:"
    $files.fullname

#Do the actual work

If ($TestMode -eq $False)
{
    
    Write-Output "Removing Files"
    
    remove-item $files -force 

}

#Finish log

$timeStamp = Get-Date -Format 'hh:mm:ss-MM-dd-yyyy'

Write-Output "$($timeStamp) Finished deleting files!"

Stop-Transcript
}
