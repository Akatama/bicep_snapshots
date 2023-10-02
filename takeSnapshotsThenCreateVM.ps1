<#
.Description
    Takes a snapshot of all of the VM's OS and Data disks
    Then copies them to another Subscription, Region and Resource Group
    Then waits for the snapshots to hydrate and creates disks from them
    Then re-creates the VM
.Example
    ./takeSnapshotsThenCreateVM.ps1 -CsvRelativePath relative/path/to/you/CSV
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

$targetCreateVMBicepPath = Join-Path -Path $PSScriptRoot -ChildPath "/bicep/createDataDisksAndVM.bicep"
$targetCreateVMBicepPathResult = Test-Path $targetCreateVMBicepPath
if(!$targetCreateVMBicepPathResult)
{
    Write-Host "Path ${$targetCreateVMBicepPath} not found!"
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

    $ResourceBaseName = "${SourceVMName}"

    $targetVmName = "${SourceVMName}-tgt"


    $sourceSnapshotDeploymentName = "source-${SourceVMName}-snapshots"

    $targetSnapshotDeploymentName = "target-${SourceVMName}-snapshots"

    Start-Sleep 120
    
    az account set --subscription $SourceSubscriptionName

    az deployment group create --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --template-file $sourceSnapshotsBicepPath --parameters SourceLocation=$SourceLocation SourceVMName=$SourceVMName `
        SourceSnapshotResourceGroupName=$SourceSnapshotResourceGroupName BaseSnapshotName=$ResourceBaseName

    $sourceOSSnapshotID = az deployment group show --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --query properties.outputs.sourceOSSnapshotID.value
    $snapshotIds = az deployment group show --resource-group $SourceResourceGroupName --name $sourceSnapshotDeploymentName `
        --query properties.outputs.sourceDataSnapshotIDs.value 
    
    $sourceDataSnapshotIDs = ConvertTo-BicepArray -ArrayToConvert $snapshotIds

    az account set --subscription $TargetSubscriptionName

    az deployment group create --resource-group $TargetResourceGroupName --name $targetSnapshotDeploymentName `
        --template-file $targetSnapshotsBicepPath --parameters TargetLocation=$TargetLocation SourceOSSnapshotID=$sourceOSSnapshotID `
        SourceDataSnapshotIDs=$sourceDataSnapshotIDs BaseSnapshotName=$ResourceBaseName

    $targetSnapshotOSName = az deployment group show --resource-group $TargetResourceGroupName --name $targetSnapshotDeploymentName `
        --query properties.outputs.targetOSSnapshotName.value

    $dataNames = az deployment group show --resource-group $TargetResourceGroupName --name $targetSnapshotDeploymentName `
        --query properties.outputs.targetDataSnapshotNames.value
    
    $targetSnapshotDataNames = @()
    
    $dataNames | ForEach-Object {
        if($_ -ne "[" -and $_ -ne "]")
        {
            $dataDiskName = $_.trim().trim(",", "`"")
            $targetSnapshotDataNames += $dataDiskName
        }
    }

    $targetOSSnapshotCompletionPercent = az snapshot show --name $targetSnapshotOSName --resource-group $TargetResourceGroupName `
        --query completionPercent
    while($targetOSSnapshotCompletionPercent -ne "100.0")
    {
        Write-Output "Waiting 30 seconds for ${targetSnapshotOSName}"
        Start-Sleep -Seconds 30
        $targetOSSnapshotCompletionPercent = az snapshot show --name $targetSnapshotOSName --resource-group $TargetResourceGroupName `
            --query completionPercent
    }

    $targetSnapshotDataNames | ForEach-Object {
        $dataSnapshotCompletionPercent = az snapshot show --name $_ --resource-group $TargetResourceGroupName `
            --query completionPercent
        while($dataSnapshotCompletionPercent -ne "100.0")
        {
            Write-Output "Waiting 30 seconds for ${$_}"
            Start-Sleep -Seconds 30
            $dataSnapshotCompletionPercent = az snapshot show --name $_ --resource-group $TargetResourceGroupName `
                --query completionPercent
        }
    }

    $dataSnapshotNamesBicep = ConvertTo-BicepArray $targetSnapshotDataNames

    $dataDisksSizeInGB = @(32, 32, 64) | ConvertTo-BicepArray

    az deployment group create --resource-group $TargetResourceGroupName --name "${targetVmName}-deploy" --template-file $targetCreateVMBicepPath `
        --parameters virtualMachineName=$targetVmName vmSize="Standard_DS1_v2" targetOSDiskName=$targetSnapshotOSName `
        targetOSSnapshotName=$targetSnapshotOSName sourceOSDiskSizeinGB=127 sourceOSDiskSkuName="Premium_LRS" `
        targetDataSnapshotNames=$dataSnapshotNamesBicep targetDataDiskName=$ResourceBaseName sourceDataDisksSinzeinGB=$dataDisksSizeInGB `
        sourceDataDisksSkuName="Premium_LRS" targetVnetName=$TargetVNetName targetSubnetName=$TargetSubnetName `
        targetVNetResourceGroupName=$TargetVNetResourceGroupName

}