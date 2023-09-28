<#
.Description
    Snaptshot a the SFPT server's OS and Data disks
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
    $TargetVNetName = $_.tgt_vnet
    $TargetVNetResourceGroupName = $_.tgt_vnet_rg
    $TargetSubnetName = $_.tgt_subnet

    $ResourceBaseName = $SourceVMName

    $targetVmName = "${ResourceBaseName}-tgt"

    $sourceSnapshotDeploymentName = "source-${ResourceBaseName}-snapshots"

    $targetSnapshotDeploymentName = "target-${ResourceBaseName}-snapshots"

    az account set --subscription $SourceSubscriptionName

    az deployment group create --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --template-file $sourceSnapshotsBicepPath --parameters SourceLocation=$SourceLocation SourceVMName=$SourceVMName `
        SourceSnapshotResourceGroupName=$SourceSnapshotResourceGroupName BaseSnapshotName=$ResourceBaseName

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
        --template-file $targetSnapshotsBicepPath --parameters TargetLocation=$TargetLocation SourceOSSnapshotID=$sourceOSSnapshotID `
        SourceDataSnapshotIDs=$sourceDataSnapshotIDs BaseSnapshotName=$ResourceBaseName
}