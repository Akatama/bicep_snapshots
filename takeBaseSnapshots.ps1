<#
.Description
    Snaptshot a the SFPT server's OS and Data disks
.Example
    ./snapshotSFTP.ps1 -CsvPath relative/path/to/you/CSV
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

$bicepPath = Join-Path -Path $PSScriptRoot -ChildPath "/bicep/snapshotThenCopy.bicep"
$bicepResult = Test-Path $bicepPath
if(!$bicepResult)
{
    Write-Host "Path ${bicepPath} not found!"
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

    Write-Host "${TargetResourceGroupName}"

    az deployment group create --resource-group $TargetResourceGroupName --name "${ResourceBaseName}-base" `
        --template-file $bicepPath --parameters SourceSubName=$SourceSubscriptionName SourceLocation=$SourceLocation TargetLocation=$TargetLocation SourceResourceGroupName=$SourceResourceGroupName `
        SourceVMName=$SourceVMName SourceSnapshotResourceGroupName=$SourceSnapshotResourceGroupName
}