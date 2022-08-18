<#
.SYNOPSIS
  Azure Function code to act as a middleman for sending webhook data from MailJet to DataDog event ingestion.
  
.DESCRIPTION
  Datadog and MailJet are not natively able to communicate. MailJet uses specific JSON payloads via WebHook wich Datadog is unable to process directly.
  Using this function, you can have MailJet send events via the fucntion URL with the function key, and have the function convert the data to be ingested as events by Datadog.

.NOTES
  Created by Michael Mardahl (github.com/mardahl)
  Please respect the MIT license and assign credit where credit is due.
  
  Remember to replace areas marked with xxxxxxxxx with actual data.

#>

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request from MailJet to Datadog."

# Interact with query parameters or the body of the request.
#Write-verbose "Raw body from Mailjet:"
#Write-Output $Request.RawBody
$jsonObj = $Request.RawBody | ConvertFrom-Json

# Get mailJet subaccountname from query string if defined along with the function URL (needed if you wish to separate data streams withing datadog as a facet)
$subaccountname = $Request.Query.subaccount
if (-not $subaccountname) {
    $subaccountname = "N/A"
}
#Write-verbose "Data transmitted from MailJet Subaccount name: $subaccountname"

#######
# Begin datadog transmission prep/send
###

$DDEndpointUri = "https://http-intake.logs.datadoghq.eu/api/v2/logs" # Notice this is the EU intake URL, change to whatever region you are using

#create header for posting JSON to datadog using API key
$DDHeaders = @{
    'Content-Type'='application/json'
    'DD-API-KEY'='xxxxxxxxxxxxxxxxxxxxxxxxx'
}

#loop thought data received from MailJet webhook.

$jsonObj | ForEach-Object {

    $mjevent = $_.event
    $mjemail = $_.email
    if (-not $mjemail) {
        $mjemail = "N/A"
    }

    #Create datadog payload...
    
    #Generate timestamp
    $uDATE = $(get-date -format u)

#JSON payload. Don't indent these lines!
$DDJSON = @"
[
{
    "ddsource": "MailjetTrigger1_AzFunction",
    "ddtags": "env:prod,version:5.1,service:MailJet,event:$mjevent,subaccount:$subaccountname,email:$mjemail",
    "hostname": "xxxxxxxxxxxxxxx",
    "message": "$uDATE,995 INFO MailJet processed a ##$mjevent## event",
    "service": "MailJet"
}
]
"@

    #send data to datadog
    #Write-verbose "Sending data to Datadog"
    #Write-verbose $DDJSON
    try {
        Invoke-RestMethod -Uri $DDEndpointUri -Headers $DDHeaders -Body $DDJSON -Method Post -UseBasicParsing -ErrorAction stop
    } catch {
        $_.Exception.Response
        $_.ErrorDetails.Message
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    #Body = $body
})
