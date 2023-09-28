@description('First part of the name of the snapshot resources')
param BaseSnapshotName string = 'snapshot'

param SourceLocation string = 'Central US'

param SourceSnapshotResourceGroupName string = 'SnapshotRG'

param SourceVMName string = 'PROD-JOB01'

var SourceSnapshotName = 'source-${BaseSnapshotName}'

resource vmToSnapShot 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name : SourceVMName
}

module sourceSnapshots 'modules/snapshot.bicep' = {
  name: SourceSnapshotName
  scope: resourceGroup(SourceSnapshotResourceGroupName)
  params: {
    snapshotName: SourceSnapshotName
    vmToSnapShot: vmToSnapShot
    snapShotLocation: SourceLocation
  }
}

output sourceOSSnapshotID string = sourceSnapshots.outputs.sourceOSSnapshotID

output sourceDataSnapshotIDs array = sourceSnapshots.outputs.sourceDataSnapshotIDs
