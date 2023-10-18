<#
.Description
    Take a consistent snapshot of a set of virtual machine's OS and data disks
    Then copies them to another subscription/region/resource group
    The way this is currently written, it expects one snapshot to be taken a day per disk
    However, the script will work even if the snapshots are taken less frequently
    More frequently and the script will need to be reworked
.Example
    ./takeSnapshot.ps1 -CsvRelativePath relative/path/to/you/CSV
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$CsvRelativePath
)

## Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)

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

#Get the function definition as a string
$converToBicepArray = ${function:ConvertTo-BicepArray}.ToString()

$csv = Import-Csv -Path $csvFilePath
$csv | ForEach-Object -ThrottleLimit $csv.Count -Parallel {
    $SourceResourceGroupName = $_.src_rg
    $SourceVMName = $_.src_vm_name
    $SourceSubscriptionName = $_.src_subscription
    $SourceSnapshotResourceGroupName = $_.src_snapshot_rg
    $SourceLocation = $_.src_region

    $TargetResourceGroupName = $_.tgt_vm_rg
    $TargetSubscriptionName = $_.tgt_subscription
    $TargetLocation = $_.tgt_region

    $date = (Get-Date).ToString("yyyyMMdd");

    $ResourceBaseName = "${SourceVMName}-${date}"


    $sourceSnapshotDeploymentName = "source-${SourceVMName}-snapshots-${date}"

    $targetSnapshotDeploymentName = "target-${SourceVMName}-snapshots-${date}"

    # define the functions inside of the thread
    ${function:ConvertTo-BicepArray} = $using:converToBicepArray

    az account set --subscription $SourceSubscriptionName

    az deployment group create --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --template-file $using:sourceSnapshotsBicepPath --parameters location=$SourceLocation sourceVMName=$SourceVMName `
        resourceGroupName=$SourceSnapshotResourceGroupName baseSnapshotName=$ResourceBaseName

    $sourceOSSnapshotID = az deployment group show --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --query properties.outputs.sourceOSSnapshotID.value
    $sourceDataSnapshotIDs = "["
    $dataSnapshotIds= az deployment group show --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --query properties.outputs.sourceDataSnapshotIDs.value 
    $sourceDataSnapshotIDs = ConvertTo-BicepArray -ArrayToConvert $dataSnapshotIds

    Write-Output "Sleeping for 120 seconds"
    Start-Sleep 120

    az account set --subscription $TargetSubscriptionName

    az deployment group create --resource-group $TargetResourceGroupName --name $targetSnapshotDeploymentName `
        --template-file $using:targetSnapshotsBicepPath --parameters location=$TargetLocation osSnapshotID=$sourceOSSnapshotID `
        dataSnapshotIDs=$sourceDataSnapshotIDs baseSnapshotName=$ResourceBaseName
}