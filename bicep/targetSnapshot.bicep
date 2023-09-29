@description('First part of the name of the snapshot resources')
param BaseSnapshotName string = 'snapshot'

param TargetLocation string = 'East US 2'

param SourceOSSnapshotID string

param SourceDataSnapshotIDs array

var TargetSnapshotName = 'target-${BaseSnapshotName}'


resource targetSnapshotOSDisk 'Microsoft.Compute/snapshots@2023-01-02' = {
  location: TargetLocation
  name: '${TargetSnapshotName}-OS'
  sku: {
    name: 'Standard_ZRS'
  }
  tags: {
    snapshotTest: 'OS'
    snapshotType: 'target'
  }
  properties: {
    osType: 'Windows'
    creationData: {
      sourceResourceId: SourceOSSnapshotID
      createOption: 'CopyStart'
    }
    incremental: true
  } 
}


resource targetSnapshotDataDisks 'Microsoft.Compute/snapshots@2023-01-02' = [for (dataSnapShotID, i) in SourceDataSnapshotIDs : {
  location: TargetLocation
  name: '${TargetSnapshotName}-Data-${i}'
  sku: {
    name: 'Standard_ZRS'
  }
  tags: {
    snapshotTest: 'Data'
    snapshotType: 'target'
  }
  properties: {
    osType: 'Windows'
    creationData: {
      sourceResourceId: dataSnapShotID
      createOption: 'CopyStart'
    }
    incremental: true
  }
}]

output targetOSSnapshotName string = targetSnapshotOSDisk.name

output targetDataSnapshotNames array = [ for i in range (0, length(SourceDataSnapshotIDs)) : targetSnapshotDataDisks[i].name]
