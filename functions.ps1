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
    [Parameter(Mandatory=$true)][Microsoft.Azure.Commands.Compute.Automation.Models.PSSnapshot[]]$DataSnapshots,
    [Parameter(Mandatory=$true)][string] $ResourceGroupName
)
{
    for($i = 0; $i -lt $DataSnapshots.Count; $i++)
    {
        $dataSnapShot = $DataSnapshots[$i]
        while($dataSnapShot.CompletionPercent -ne 100)
        {
            Start-Sleep -Seconds 30
            Write-Log "Waiting for 30 seconds. Data Incremental Snapshot #${i} Completion percent is: $($dataSnapShot.CompletionPercent)"
            $dataSnapShot = Get-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $dataSnapShot.Name
        }
    }
}