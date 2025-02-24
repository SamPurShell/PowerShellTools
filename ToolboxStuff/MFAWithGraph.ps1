#You will need to connect to PSGraph before running this. 

Function Check-MFA
{

Get-UserAccount -MGGraph #This is a separate function to capture a users account object in the specified format, such as MGUser.

Write-Host "Checking MFA Status of $($MgUser.UserPrincipalName)" -ForegroundColor Yellow

$MFADataObject = [PSCustomObject]@{
    user               = $($MgUser.UserPrincipalName)
    MFAstatus          = "_"
    email              = "-"
    phone              = "-"
    softwareoath       = "-"
    fido2              = "-"
    app                = "-"
    password           = "-"
    tempaccess         = "-"
    hellobusiness      = "-"
}

$MFAData = Get-MgUserAuthenticationMethod -UserId $MgUser.UserPrincipalName
    ForEach ($method in $MFAData)
    {
    Switch ($method.AdditionalProperties["@odata.type"]) {
          "#microsoft.graph.emailAuthenticationMethod"  { 
             $MFADataObject.email = $true 
                # When only the email is set, then MFA is disabled.
                if($MFADataObject.MFAstatus -ne "Enabled")
                {
                    $MFADataObject.MFAstatus = "Disabled"
                }  
          } 
          "#microsoft.graph.fido2AuthenticationMethod"                   { 
            $MFADataObject.fido2 = $true 
            $MFADataObject.MFAstatus = "Enabled"
          }    
          "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"  { 
            $MFADataObject.app = $true 
            $MFADataObject.MFAstatus = "Enabled"
          }    
          "#microsoft.graph.passwordAuthenticationMethod"                {              
                $MFADataObject.password = $true 
                # When only the password is set, then MFA is disabled.
                if($MFADataObject.MFAstatus -ne "Enabled")
                {
                    $MFADataObject.MFAstatus = "Disabled"
                }                
           }     
           "#microsoft.graph.phoneAuthenticationMethod"  { 
            $MFADataObject.phone = $true 
            $MFADataObject.MFAstatus = "Enabled"
          }   
            "#microsoft.graph.softwareOathAuthenticationMethod"  { 
            $MFADataObject.softwareoath = $true 
            $MFADataObject.MFAstatus = "Enabled"
          }           
            "#microsoft.graph.temporaryAccessPassAuthenticationMethod"  { 
            $MFADataObject.tempaccess = $true 
            $MFADataObject.MFAstatus = "Enabled"
          }           
            "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod"  { 
            $MFADataObject.hellobusiness = $true 
                # When only HFB is set, then MFA is disabled.
                if($MFADataObject.MFAstatus -ne "Enabled")
                {
                    $MFADataObject.MFAstatus = "Disabled"
                }    
          }                   
        }
    }

Write-Host "Please review all of $($MFADataObject.user)'s authentication methods below:" -ForegroundColor Yellow

$MFADataObject

    If ($MFADataObject.MFAstatus -ne "Enabled")
    {
    write-host "$($MFADataObject.user) does not have an accepted form of MFA set up. Please have them go to MFASetup.corneagen.com to set it up." -ForegroundColor Yellow
    }
    Else
    {
    write-host "$($MFADataObject.user) has an acceptable form of MFA set up!" -ForegroundColor Green
       do
        {
        write-host "Would you like to remove all of $($MFADataObject.user)'s useable MFA methods so that they can re-register for MFA?" -ForegroundColor Yellow
        Write-Host "     1: Yes - remove these methods for this user so they can re-register."
        Write-Host "     2: No - keep this user the way it is, I was just checking."
        $MFAResetInput = Read-Host "`nPlease make a selection"
        }
        until (($MFAResetInput -eq '1') -or ($MFAResetInput -eq '2'))
    }
    If ($MFAResetInput -eq 1)
    {
        do
        {
        write-host "The MFA methods listed below will be removed from $($MFADataObject.user)'s account in order to allow them to re-register. Press 1 to confirm, or press 2 to cancel." -ForegroundColor Yellow
        $MFAResetObject = $MFADataObject | Select-Object phone, softwareoath, app, tempaccess
        $MethodsToReset = $MFAResetObject | Get-Member -MemberType Properties | Where-Object {$MFAResetObject.$($_.Name) -eq $true} | ForEach-Object { 
        "$($_.Name)"}
        $MethodsToReset
        Write-Host "     1: Confirm"
        Write-Host "     2: Cancel - return to main menu."
        $MFAResetConfirm = Read-Host "`nPlease make a selection"
        }
        until (($MFAResetConfirm -eq '1') -or ($MFAResetConfirm -eq '2'))
    }
        If ($MFAResetConfirm -eq '1')
        {
        write-host "Resetting $($MFADataObject.user)'s MFA methods now, please wait..." -ForegroundColor Yellow
        Do{
        $OneMoreTime = $null
        $OneMoreTimeCount++

           ForEach ($EnabledMethod in $MethodsToReset)
       {
            switch ($EnabledMethod)
         {
            "phone" {
                $PhoneMethods = Get-MgUserAuthenticationPhoneMethod -UserId $MgUser.id
                If ($Null -ne $PhoneMethods)
                {
                        ForEach ($PhoneMethod in $PhoneMethods)
                        {
                        Remove-MgUserAuthenticationPhoneMethod -UserId $MgUser.id -PhoneAuthenticationMethodId $PhoneMethod.Id -ErrorAction SilentlyContinue -ErrorVariable OneMoreTime
                        }
                }
            }

            "softwareoath" {
                $SoftwareoathMethods = Get-MgUserAuthenticationSoftwareOathMethod -UserId $MgUser.id
                If ($Null -ne $SoftwareoathMethods)
                {   
                    ForEach ($SoftwareoathMethod in $SoftwareoathMethods)
                            {
                            Remove-MgUserAuthenticationSoftwareOathMethod -UserId $MgUser.id -SoftwareOathAuthenticationMethodId $SoftwareoathMethod.Id -ErrorAction SilentlyContinue -ErrorVariable OneMoreTime
                            }   
                }
            }

            "app" {
                $AppMethods = Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $MgUser.id
                If ($Null -ne $AppMethods)
                {
                    ForEach ($AppMethod in $AppMethods)
                        {
                        Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $MgUser.id -MicrosoftAuthenticatorAuthenticationMethodId $AppMethod.Id -ErrorAction SilentlyContinue -ErrorVariable OneMoreTime
                        }
                }
            }

            "fido2" {
                $Fido2Methods = Get-MgUserAuthenticationFido2Method -UserId $MgUser.id
                If ($Null -ne $Fido2Methods)
                {
                        ForEach ($Fido2Method in $Fido2Methods)
                        {
                        Remove-MgUserAuthenticationFido2Method -UserId $MgUser.id -Fido2AuthenticationMethodId $Fido2Method.Id -ErrorAction SilentlyContinue -ErrorVariable OneMoreTime
                        }
                }
            }

            "tempaccess" {
                $TempAccessMethods = Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $MgUser.id
                If ($Null -ne $TempAccessMethods)
                {
                        {
                        Remove-MgUserAuthenticationTemporaryAccessPassMethod -UserId $MgUser.id -TemporaryAccessPassAuthenticationMethodId $TempAccessMethod.Id -ErrorAction SilentlyContinue -ErrorVariable OneMoreTime
                        }
                }
            }
        }
      }
      If ($null -ne $OneMoreTime)
      {
        start-sleep -Seconds 3
      }     
    }
    Until (($null -eq $OneMoreTime) -or ($OneMoreTimeCount -eq '10'))

    If ($OneMoreTimeCount -eq '10')
    {
    write-host "Unable to remove all authentication methods. Please check the account in Azure and remove any authentication methods manually."
    }
    

write-host "DONE!" -ForegroundColor Green
    }        
}
