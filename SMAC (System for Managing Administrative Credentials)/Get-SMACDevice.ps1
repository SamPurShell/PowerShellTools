#You will need to get an access token to Graph with at least read access to the storage table that you wrote to on the client script before running this. This can be an automated process.

Function Get-SMACDevice
{
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement

Write-host "Starting the SMAC tool lookup function. Let's get to SMAC'in!" -ForegroundColor Yellow

  do
  {
  try {
  $Computer = Read-Host "Please input the computer name that you would search"
  $Computer = $computer.ToUpper()
  $PartitionKey = "SomeKey" #this should be the same for all rows in your SMAC table
  $RowKey = $computer
  $URI = $URL + '(PartitionKey=' +"'" + $($PartitionKey) + "'" + ' ,RowKey='+"'"+ $($RowKey) + "'" + ")"
  $headers = @{
        "Authorization" = "Bearer $accessToken"
        "x-ms-version" = "2017-11-09"
        "Accept" = "application/json;odata=nometadata"
    }

  $TableData = Invoke-webrequest $uri -Method Get -ContentType 'application/json' -Headers $headers -UseBasicParsing -ErrorVariable ErrorMessage
      $table = New-Object System.Data.Datatable
      [void]$table.Columns.Add("Hostname")
      [void]$table.Columns.Add("Local Admin Account")
      [void]$table.Columns.Add("Public IP")
      [void]$table.Columns.Add("Last Update")
      [void]$table.Columns.Add("Current Password")
      [void]$table.Columns.Add("Old Password")
      
      If ($TableData.IsValid -eq '1')
      {
      $CurrentPassword = $TableData.Password1
      $OldPassword = $TableData.Password2
      }

      If ($TableData.IsValid -eq '2')
      {
      $CurrentPassword = $TableData.Password2
      $OldPassword = $TableData.Password1
      }

      [void]$table.Rows.Add($TableData.Hostname, $TableData.Account, $TableData.PublicIP, $TableData.LastUpdate, $CurrentPassword, $OldPassword)
      $table | format-table

      Set-Clipboard -Value $CurrentPassword
      write-host "Current Password has been copied to your clipboard." -ForegroundColor Green
   }
   catch {
      $FailurePrompt = Read-host "Sorry, I couldn't find that record. Please press Enter to search again, or type 'q' to quit"
      $TableData = $Null
      If ($FailurePrompt -eq 'q')
      {
      Run-CGToolbox-Menu
      }
   }
   }
   Until ($Null -ne $TableData)

  do{
  Write-Output "Would you like to search for another computer?"
  Write-Host "     1: Yes"
  Write-Host "     2: No"
  $RetryInput = Read-Host "`nPlease make a selection"
  }
  until (($RetryInput -eq '1') -or ($RetryInput -eq '2'))

  If ($RetryInput -eq '1')
  {
  Get-SMACDevice
  }

  If ($RetryInput -eq '2')
  {
  Run-CGToolbox-Menu
  }
}