<#
.Description
    Take a base snapshot of a set of virtual machine's OS and data disks
    Then copies them to another subscription/region/resource group
.Example
    ./takeBaseSnapshots.ps1 -CsvRelativePath relative/path/to/you/CSV
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$CsvRelativePath
)

$csvFilePath = Join-Path -Path $PSScriptRoot -ChildPath $CsvRelativePath
$csvFileResult = Test-Path $csvFilePath
if(!$csvFileResult)
{
    Write-Host "Path ${csvFilePath} not found!"
    exit
}

$sourceSnapshotsBicepPath = Join-Path -Path $PSScriptRoot -ChildPath "/bicep/sourceSnapshot.bicep"
$sourceSnapshotsBicepResult = Test-Path $sourceSnapshotsBicepPath 
if(!$sourceSnapshotsBicepResult)
{
    Write-Host "Path ${sourceSnapshotsBicepPath} not found!"
    exit
}

$targetSnapshotsBicepPath = Join-Path -Path $PSScriptRoot -ChildPath "/bicep/targetSnapshot.bicep"
$targetSnapshotsBicepResult = Test-Path $targetSnapshotsBicepPath
if(!$targetSnapshotsBicepResult)
{
    Write-Host "Path ${targetSnapshotsBicepPath} not found!"
    exit
}



Import-Csv -Path $csvFilePath | ForEach-Object {
    $SourceResourceGroupName = $_.src_rg
    $SourceVMName = $_.src_vm_name
    $SourceSubscriptionName = $_.src_subscription
    $SourceSnapshotResourceGroupName = $_.src_snapshot_rg
    $SourceLocation = $_.src_region

    $TargetResourceGroupName = $_.tgt_vm_rg
    $TargetSubscriptionName = $_.tgt_subscription
    $TargetLocation = $_.tgt_region

    $ResourceBaseName = "${SourceVMName}-base"


    $sourceSnapshotDeploymentName = "source-${SourceVMName}-snapshots-base"

    $targetSnapshotDeploymentName = "target-${SourceVMName}-snapshots-base"

    az account set --subscription $SourceSubscriptionName

    az deployment group create --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --template-file $sourceSnapshotsBicepPath --parameters location=$SourceLocation sourceVMName=$SourceVMName `
        resourceGroupName=$SourceSnapshotResourceGroupName baseSnapshotName=$ResourceBaseName

    $sourceOSSnapshotID = az deployment group show --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --query properties.outputs.sourceOSSnapshotID.value
    $sourceDataSnapshotIDs = "["
    $snapshotIds = az deployment group show --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --query properties.outputs.sourceDataSnapshotIDs.value 
    $snapshotIds | ForEach-Object {
        if ($_ -ne "[" -and $_ -ne "]")
        {
            $dataDiskId = $_.trim().trim(",", "`"")
            $dataDiskId = -join("`'", $dataDiskId, "`'", ",")
            $sourceDataSnapshotIDs = -join($sourceDataSnapshotIDs, $dataDiskId)
        }
    }
    $sourceDataSnapshotIDs = $sourceDataSnapshotIDs.trim(",")
    $sourceDataSnapshotIDs = -join($sourceDataSnapshotIDs, "]")

    az account set --subscription $TargetSubscriptionName

    az deployment group create --resource-group $TargetResourceGroupName --name $targetSnapshotDeploymentName `
        --template-file $targetSnapshotsBicepPath --parameters location=$TargetLocation osSnapshotID=$sourceOSSnapshotID `
        dataSnapshotIDs=$sourceDataSnapshotIDs baseSnapshotName=$ResourceBaseName
}