@description('First part of the name of the snapshot resources')
param baseSnapshotName string = 'snapshot'

param location string = 'Central US'

param resourceGroupName string = 'SnapshotRG'

@description('Name of the VM to snapshot the disks of')
param sourceVMName string = 'PROD-JOB01'

var snapshotName = 'source-${baseSnapshotName}'

resource vmToSnapShot 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name : sourceVMName
}

module sourceSnapshots 'modules/snapshot.bicep' = {
  name: snapshotName
  scope: resourceGroup(resourceGroupName)
  params: {
    snapshotName: snapshotName
    vmToSnapShot: vmToSnapShot
    location: location
  }
}

output sourceOSSnapshotID string = sourceSnapshots.outputs.sourceOSSnapshotID

output sourceDataSnapshotIDs array = sourceSnapshots.outputs.sourceDataSnapshotIDs

output vmSize string = vmToSnapShot.properties.hardwareProfile.vmSize
