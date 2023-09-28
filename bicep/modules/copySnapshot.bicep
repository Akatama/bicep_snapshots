param sourceOSSnapshotID string

param sourceDataSnapshotIDs array

param targetLocation string

param targetSnapshotName string

resource targetSnapshotOSDisk 'Microsoft.Compute/snapshots@2023-01-02' = {
  location: targetLocation
  name: '${targetSnapshotName}-OS'
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
      sourceResourceId: sourceOSSnapshotID
      createOption: 'CopyStart'
    }
    incremental: true
  } 
}


resource targetSnapshotDataDisks 'Microsoft.Compute/snapshots@2023-01-02' = [for (dataSnapShotID, i) in sourceDataSnapshotIDs : {
  location: targetLocation
  name: '${targetSnapshotName}-Data-${i}'
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
