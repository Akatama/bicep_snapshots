param sourceOSSnapshotID string

param sourceDataSnapshotIDs array

param location string

param targetSnapshotName string

param targetVMName string

param osDiskSkuName string

param dataDiskSkuName string

resource targetSnapshotOSDisk 'Microsoft.Compute/snapshots@2023-01-02' = {
  location: location
  name: '${targetSnapshotName}-OS'
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
  location:location
  name: '${targetSnapshotName}-Data-${i}'
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

resource targetOSDisk 'Microsoft.Compute/disks@2023-01-02' = {
  name: '${targetVMName}_OS_disk'
  location: location
  tags: {
    snapshotTest: 'OS'
    snapshotType: 'target'
  }
  sku: {
    name: osDiskSkuName
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: targetSnapshotOSDisk.id
    }
  }
}

resource targetDataDisks 'Microsoft.Compute/disks@2023-01-02' = [for i in range(0, length(sourceDataSnapshotIDs)) : {
  name: '${targetVMName}_Data_disk_${i}'
  location: location
  tags: {
    snapshotTest: 'data'
    snapshotType: 'target'
  }
  sku: {
    name: dataDiskSkuName
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: targetSnapshotDataDisks[i].id
    }
  }
}]

output osDisk object = targetOSDisk

output dataDisks array = [ for i in range (0, length(sourceDataSnapshotIDs)) : targetDataDisks[i]]
