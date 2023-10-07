# various functions

function ConvertTo-BicepArray
(
    [Parameter(Mandatory=$true)][String[]]$ArrayToConvert 

)
{
    $BicepArray = "["
    $ArrayToConvert  | ForEach-Object {
    
        if ($_ -ne "[" -and $_ -ne "]")
        {
            $ArrayElement = $_.trim().trim(",", "`"")
            $ArrayElement = -join("`'", $ArrayElement, "`'", ",")
            $BicepArray = -join($BicepArray, $ArrayElement)
        }
    }
    $BicepArray = $BicepArray.trim(",")
    $BicepArray = -join($BicepArray, "]")
    return $BicepArray
}

function Wait-DataSnapshots
(
    [Parameter(Mandatory=$true)][string[]]$DataSnapshots,
    [Parameter(Mandatory=$true)][string] $ResourceGroupName
)
{
    for($i = 0; $i -lt $DataSnapshots.Count; $i++)
    {
        $dataSnapShot = $DataSnapshots[$i]
        $dataSnapshotCompletionPercent = az snapshot show --name $dataSnapShot --resource-group $ResourceGroupName `
            --query completionPercent
        while($dataSnapshotCompletionPercent -ne "100.0")
        {
            Start-Sleep -Seconds 30
            Write-Log "Waiting for 30 seconds. Data Incremental Snapshot #${i} Completion percent is: $($dataSnapshotCompletionPercent)"
            $dataSnapshotCompletionPercent = az snapshot show --name $dataSnapShot --resource-group $ResourceGroupName `
                --query completionPercent
        }
    }
}