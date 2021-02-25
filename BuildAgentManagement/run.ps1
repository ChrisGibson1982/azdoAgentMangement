# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

############ functions ############

function Set-ScaleSet {
    [CmdletBinding(SupportsShouldProcess)]
    Param
    (

        [Parameter(
            Mandatory = $true,
            HelpMessage = "Name of the target scale set"
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $targetScaleSetId,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "devops Username"
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $username,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "devops PAT"
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $PAT,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "Name of the target scale set"
        )]
        [ValidateNotNullOrEmpty()]
        [int]
        $desiredIdleCount,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "Maximum number of instances"
        )]
        [ValidateNotNullOrEmpty()]
        [int]
        $maxCapacity,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "Recycle instances after each job"
        )]
        [ValidateNotNullOrEmpty()]
        [bool]
        $recycleAfterEachUse,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "devops organisation name"
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $orgName
    )

    Begin {
    }
    Process {
        If ($PSCmdlet.ShouldProcess("Create new SQL Token and publish as pipeline variable")) {
            $DevOpsCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $PAT)))

            $BodySource = @"
    {
        "recycleAfterEachUse":false,"maxSavedNodeCount":0,"maxCapacity":<<maxCapacity>>,"desiredIdle":<<desiredIdle>>,"timeToLiveMinutes":15,"agentInteractiveUI":false
    }
"@
            $jsonBody = $BodySource.replace("<<desiredIdle>>", $desiredIdleCount).replace("<<maxCapacity>>", $maxCapacity).replace("<<recycleAfterEachUse>>", $recycleAfterEachUse)

            Write-Output "jsonBody:"
            $jsonBody

            $setElasticPoolsUri = "https://dev.azure.com/$orgName/_apis/distributedtask/elasticpools/" + $targetScaleSetId + "?api-version=6.1-preview.1"

            Write-Output "setElasticPoolsUri: $($setElasticPoolsUri)"

            Write-Output "Set Scale Set Response for: $targetScaleSetId"

            Invoke-RestMethod -Uri $setElasticPoolsUri -Method Patch -Body $jsonBody -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $DevOpsCreds) }

        } # End $PSCmdlet.ShouldProcess
    }
    End {

    }
}
####################################


# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

Write-Host "PowerShell timer trigger function Started at UTC TIME: $currentUTCtime"

$username = $env:azdoUser
$PAT = $env:azdoPAT
$targetScaleSets = $env:azdoScaleSets
$desiredIdle = $env:desiredIdle
$powerOnHour = $env:PowerOnHour
$powerOffHour = $env:PowerOffHour
$recycleAfterEachUse = $env:recycleAfterEachUse
$maxCapacity = $env:maxCapacity
$orgName = $env:orgName


$DevOpsCreds = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $PAT)))
$d = Get-Date

$getElasticPoolsUri = "https://dev.azure.com/$orgName/_apis/distributedtask/elasticpools?api-version=6.1-preview.1"
Write-Output "getElasticPoolsUri: $($getElasticPoolsUri)"

$getElasticPoolsUriResponse = (Invoke-RestMethod -Uri $getElasticPoolsUri -Method Get -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $DevOpsCreds) }).value

if ($getElasticPoolsUriResponse) {

    if ((($d.DayOfWeek -notmatch "Sat") -or ($d.DayOfWeek -notmatch "Sun")) -and (($d.Hour -ge $powerOnHour ) -and ($d.Hour -lt $powerOffHour ))) {
        Write-Information -InformationAction Continue -MessageData "Weekday between 7am and 7pm"


        foreach ($item in $getElasticPoolsUriResponse) {
            $scalesetName = ($item.azureId).split("/")[8]
            $poolID = $item.poolid
            Write-Output "Main Script Pool ID: $($poolID)"
            Write-Output "Main Script desired Idle: $($desiredIdle)"

            Write-Information -InformationAction Continue -MessageData "Name: $scalesetName"

            if ($targetScaleSets -match $scalesetName) {
                Write-Information -InformationAction Continue -MessageData "Found scaleset: $scalesetName"

                Set-ScaleSet -targetScaleSetId $poolID -desiredIdleCount $desiredIdle -username $username -PAT $pat -maxCapacity 4 -recycleAfterEachUse $false


            }
            else {
                Write-Information -InformationAction Continue -MessageData "Did not find scaleset: $scalesetName"
            }
        } # End of foreach ($item in $getElasticPoolsUriResponse){


    } # End of if (($d.DayOfWeek -ne "Saturday") -or ($d.DayOfWeek -ne "Sunday")) {
    elseif ((($d.DayOfWeek -notmatch "Sat") -or ($d.DayOfWeek -notmatch "Sun")) -and (($d.Hour -lt $powerOnHour ) -and ($d.Hour -gt $powerOffHour ))) {
        Write-Information -InformationAction Continue -MessageData "Weekday between 7pm and 7am"


        foreach ($item in $getElasticPoolsUriResponse) {
            $scalesetName = ($item.azureId).split("/")[8]
            $poolID = $item.poolid

            Write-Information -InformationAction Continue -MessageData "Name: $scalesetName"

            if ($targetScaleSets -match $scalesetName) {
                Write-Information -InformationAction Continue -MessageData "Found scaleset: $scalesetName"


                Set-ScaleSet -targetScaleSetId $poolID -desiredIdleCount 0 -username $username -PAT $pat -maxCapacity 4 -recycleAfterEachUse $false
            }
            else {
                Write-Information -InformationAction Continue -MessageData "Did not find scaleset: $scalesetName"
            }
        } # End of foreach ($item in $getElasticPoolsUriResponse){


    } # End of elseif (($d.DayOfWeek -ne "Saturday") -or ($d.DayOfWeek -ne "Sunday"))
    else {
        Write-Information -InformationAction Continue -MessageData "Weekend"


        foreach ($item in $getElasticPoolsUriResponse) {
            $scalesetName = ($item.azureId).split("/")[8]
            $poolID = $item.poolid

            Write-Information -InformationAction Continue -MessageData "Name: $scalesetName"

            if ($targetScaleSets -match $scalesetName) {
                Write-Information -InformationAction Continue -MessageData "Found scaleset: $scalesetName"


                Set-ScaleSet -targetScaleSetId $poolID -desiredIdleCount 0 -username $username -PAT $pat  -maxCapacity 4 -recycleAfterEachUse $false
            }
            else {
                Write-Information -InformationAction Continue -MessageData "Did not find scaleset: $scalesetName"
            }
        } # End of foreach ($item in $getElasticPoolsUriResponse){
    }
} # End of if($getElasticPoolsUriResponse){
else {
    Write-Error "No response from get elastic pool request"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function finished at TIME: $currentUTCtime"