@description('First part of the name of the snapshot resources')
param BaseSnapshotName string = 'snapshot'

param SourceSubName string

param SourceLocation string = 'Central US'

param TargetLocation string = 'East US 2'

param SourceResourceGroupName string = 'prod-automation-sg'

param SourceSnapshotResourceGroupName string = 'SnapshotRG'

param SourceVMName string = 'PROD-JOB01'

var SourceSnapshotName = 'source-${BaseSnapshotName}'

var TargetSnapshotName = 'target-${BaseSnapshotName}'

resource vmToSnapShot 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name : SourceVMName
  scope: resourceGroup(SourceResourceGroupName)
}

module sourceSnapshots 'modules/snapshot.bicep' = {
  name: 'sourceSnapshots'
  scope: resourceGroup(SourceSnapshotResourceGroupName)
  params: {
    snapshotName: SourceSnapshotName
    vmToSnapShot: vmToSnapShot
    snapShotLocation: SourceLocation
  }
}

module targetSnapshots 'modules/copySnapshot.bicep' = {
  name: 'targetSnapshots'
  params: {
    targetSnapshotName: TargetSnapshotName
    sourceOSSnapshotID: sourceSnapshots.outputs.sourceOSSnapshotID
    sourceDataSnapshotIDs: sourceSnapshots.outputs.sourceDataSnapshotIDs
    location: TargetLocation
  }
}
