@description('First part of the name of the snapshot resources')
param snapshotName string = 'snapshot'

param sourceLocation string = 'Central US'

param targetLocation string = 'East US 2'

param osDiskSkuName string = 'Premium_LRS'

param dataDiskSkuName string = 'Premium_LRS'

var sourceResourceGroupName = 'cas-pr-automation-sg'

var sourceVMName = 'REP-PR-JOB01-src'

var targetResourceGroupName = 'cas-dr-automation-rg'

var targetVMName = 'REP-PR-JOB01-tgt'

var sourceSnapshotName = 'source-${snapshotName}'

var targetSnapshotName = 'target-${snapshotName}'

resource vmToSnapShot 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name : sourceVMName
  scope: resourceGroup(sourceResourceGroupName)
}

module sourceSnapshots 'modules/snapshot.bicep' = {
  name: 'sourceSnapshots'
  scope: resourceGroup(sourceResourceGroupName)
  params: {
    snapshotName: sourceSnapshotName
    vmToSnapShot: vmToSnapShot
    snapShotLocation: sourceLocation
  }
}

module targetSnapshots 'modules/copySnapshot.bicep' = {
  name: 'targetSnapshots'
  params: {
    targetSnapshotName: targetSnapshotName
    sourceOSSnapshotID: sourceSnapshots.outputs.sourceOSSnapshotID
    sourceDataSnapshotIDs: sourceSnapshots.outputs.sourceDataSnapshotIDs
    location: targetLocation
    targetVMName: targetVMName
    osDiskSkuName: osDiskSkuName
    dataDiskSkuName: dataDiskSkuName
  }
}
