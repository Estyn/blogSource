---
title: "Azure Dev Machine Auto Shutdown Part 2"
date: 2013-09-06
comments: true
categories: [Azure,VM,PowerShell,Twillio,Dev VM]
keywords: "azure, development,Twillio,Virtual Machine,VM,PowerShell"

---
In [Part 1](/blog/2013/09/03/auto-shutdown-for-windows-azure-vm/) we looked at how to set-up a simple script to shut down an azure virtual machine after a period of inactivity.  The problem I had with the previous solution was determining the amount of inactivity time to set the script to run at.  I often found the machine was shutting down when I didn't want it to.  In this post we will add SMS notification when the machine is about to shut down and we will add an option for cancelling the shut down.
 <!-- more -->
## Step 1: Get a [Twillio](https://www.twilio.com/user/account) account if you don't already have one.
Twillio has a free trial account that will allow you to send free SMS's to your own phone.  Once you have a Twillio account you will need to write down your Account SID and you Auth Token, both can be found on the main account page in Twillio.  You will also need to write down your Twillio phone number.

## Step 2: Get the Twillio and RestSharp dll
In order to use Twillio from powershell we will need to have a copy of  Twillio.API.dll which has a dependency on  RestSharp.dll so we will need that as well.  I've found NuGet to be the easiest way to get both.
{{< highlight powershell >}}Install-Package Twilio
{{< /highlight >}}
{{< highlight powershell >}}
Install-Package RestSharp`
{{< /highlight >}}

Once you have the dlls save them in the same folder as your script.

## Step 3: Modify the script to send an SMS prior to shutting down
{{< highlight powershell >}}
Add-Type -path "c:\Twilio.Api.dll"
Add-Type -path "c:\RestSharp.dll"
$twilio = new-object Twilio.TwilioRestClient("YOURACCOUNTSID", "YOURAUTHTOKEN")
$msg = $twilio.SendSmsMessage("YOURTWILLIONUMBER", "YOURCELLPHONENUMBER", "VM about to shutdown")
{{< /highlight >}}
    
   
## Step 4: Add a delay to the script
Having a notification that the VM is about to shut down isn't very useful if you can't do anything about it so we will add a delay so that you can cancel the shut down after having received the notification.

I'm using a nice script by [Jeffery Hicks](http://jdhitsolutions.com/blog/2012/04/friday-fun-powershell-countdown/) that displays a nice countdown message on the screen before executing the shut down.  You can read his blog post to see how the script works.  The complete script is listed below, it sends an SMS then waits 15 minutes before executing the shut down command. The countdown can be interrupted with the esc key to prevent the shut down.

{{< highlight powershell >}}

<#
 -----------------------------------------------------------------------------
 Script: Countdown2.ps1
 Version: 0.9
 Author: Jeffery Hicks
    http://jdhitsolutions.com/blog
    http://twitter.com/JeffHicks
    http://www.ScriptingGeek.com
 Date: 4/27/2012
 Keywords:
 Comments:
 This is a variation on the Start-Countdown script from Josh Atwell
 (http://www.vtesseract.com/post/21414227113/start-countdown-function-a-visual-for-start-sleep)

 "Those who forget to script are doomed to repeat their work."

  ****************************************************************
  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
  ****************************************************************
 -----------------------------------------------------------------------------
 #>
 
Import-Module "C:\Program Files (x86)\Microsoft SDKs\Windows Azure\PowerShell\Azure\Azure.psd1"
Function Start-Countdown {
<#
	.Synopsis
	 Initiates a countdown before running a command
    
    .Description  
     This is a variation on the Start-Countdown script from Josh Atwell
     (http://www.vtesseract.com/post/21414227113/start-countdown-function-a-visual-for-start-sleep). 
     It can be used instead of Start-Sleep and provides a visual countdown 
     progress during "sleep" times. At the end of the countdown, your 
     command will execute. Press the ESC key any time during the countdown
     to abort. 
     
     USING START-COUNTDOWN IN THE POWERSHELL ISE
     Results will vary slightly in the PowerShell ISE. If you use this in
     the ISE, it is recommended to use -Clear. You also cannot use the ESC
     key to abort the script if using the console. You'll need to press
     Ctrl+C. If using the progress bar, there is a Stop button in the ISE.
     If you abort in the ISE, you won't get the warning message.
     
     .Parameter Seconds
     The number of seconds to countdown. The default is 10.
     
     .Parameter Scriptblock
     A PowerShell scriptblock to execute at the end of the countdown.
     
     .Parameter ProgressBar
     Use a progress bar instead of the console.
     
     .Parameter Clear
     Clear the screen. Other wise, the countdown will use the current location.
     
     .Parameter Message
     The message to be displayed at the end of the countdown before any
     scriptblock is executed.
     	 
	.Example
	 PS C:\> Start-Countdown -Seconds 10 -clear
	 
	 This method will clear the screen and display descending seconds
	
	.Example
	 PS C:\> Start-Countdown -Seconds 30 -ProgressBar -scriptblock {get-service -comp (get-content computers.txt)}
	 
	 This method will display a progress bar on screen. At the end of the countdown the scriptblock will execute.
	 	 
	.Link
	 http://jdhitsolutions.com/blog
     
     .Link
     Write-Progress
	
#>
Param(
[Parameter(Position=0,HelpMessage="Enter seconds to countdown from")]
[Int]$Seconds = 10,
[Parameter(Position=1,Mandatory=$False,
HelpMessage="Enter a scriptblock to execute at the end of the countdown")]
[scriptblock]$Scriptblock,
[Switch]$ProgressBar,
[Switch]$Clear,
[String]$Message = "Sutting down VM"
)

#save beginning value for total seconds
$TotalSeconds=$Seconds

#get current cursor position
$Coordinate = New-Object System.Management.Automation.Host.Coordinates
$Coordinate.X=$host.ui.rawui.CursorPosition.X
$Coordinate.Y=$host.ui.rawui.CursorPosition.Y

If ($clear) {
    Clear-Host
    #find the middle of the current window
    $Coordinate.X=[int]($host.ui.rawui.WindowSize.Width/2)
    $Coordinate.Y=[int]($host.ui.rawui.WindowSize.Height/2)
}

#define the Escape key
$ESCKey = 27

#define a variable indicating if the user aborted the countdown
$Abort=$False

while ($seconds -ge 1) {

    if ($host.ui.RawUi.KeyAvailable)
    		{
    		$key = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown")

    		if ($key.VirtualKeyCode -eq $ESCkey)
    			{
                #ESC was pressed so quit the countdown and set abort flag to True
    			$Seconds = 0
                $Abort=$True 
    			}
    		}

    If($ProgressBar){
        #calculate percent time remaining, but in reverse so the progress bar
        #moves from left to right
        $percent=100 - ($seconds/$TotalSeconds)*100
    	Write-Progress -Activity "Countdown" -SecondsRemaining $Seconds -Status "Shutting doown in (esc to cancel)" -PercentComplete $percent
    	Start-Sleep -Seconds 1
    } Else {
        if ($Clear) {
          Clear-Host
        } 
        $host.ui.rawui.CursorPosition=$Coordinate
        #write the seconds with padded trailing spaces to overwrite any extra digits such
        #as moving from 10 to 9
        $pad=($TotalSeconds -as [string]).Length
        if ($seconds -le 10) {
            $color="Red"
        }
        else {
            $color="Green"
        }
        Write-Host "ESC to cancel: $(([string]$Seconds).Padright($pad))" -foregroundcolor $color
    	Start-Sleep -Seconds 1
    }
    #decrement $Seconds
    $Seconds--
} #while

if ($Progress) {
        #set progress to complete
        Write-Progress -Completed
    }

if (-Not $Abort) {
    
    if ($clear) {
        #if $Clear was used, center the message in the console
        $Coordinate.X=$Coordinate.X - ([int]($message.Length)/2)
    }

    $host.ui.rawui.CursorPosition=$Coordinate
    
    Write-Host $Message -ForegroundColor Green
    #run the scriptblock if specified
    if ($scriptblock) {    
        Invoke-Command -ScriptBlock $Scriptblock
    }
}
else {
    Write-Warning "Countdown aborted"
}

} #end function
$sb = {Stop-AzureVM -Name "YOURVMNAME" -ServiceName "YOURSERVICENAME" -Force}
 Add-Type -path "c:\Twilio.Api.dll"
    Add-Type -path "c:\RestSharp.dll"
    $twilio = new-object Twilio.TwilioRestClient("YOURACCOUNTSID", "YOURAUTHTOKEN")
    $msg = $twilio.SendSmsMessage("YOURTWILLIONUMBER", "YOURCELLPHONENUMBER", "VM about to shutdown")
Start-Countdown 900 -Scriptblock $sb -ProgressBar  -Clear


{{< /highlight >}}