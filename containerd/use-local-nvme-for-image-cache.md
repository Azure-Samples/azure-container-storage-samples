# Use ephemeral NVMe data disks for container image cache

Container image caching is a critical performance optimization strategy in Kubernetes environments. When nodes need to pull container images, especially large images or during high-scale deployments, the image pull process can become a significant bottleneck affecting pod startup times and overall application performance. By leveraging ephemeral NVMe data disks for container image cache, you can dramatically improve image pull speeds, reduce network bandwidth consumption, and accelerate pod scheduling in your AKS clusters.

## Understanding container image cache

Container image caching involves storing downloaded container images locally on nodes to avoid repeated downloads from container registries. In AKS, the container runtime (containerd) manages this cache, storing image layers on the node's local storage. When a pod requires an image that's already cached, the container runtime can start the container immediately without network latency or registry throttling delays.

Key benefits of efficient container image caching include:

- **Faster pod startup times**: Eliminates the need to download images for subsequent pod deployments
- **Reduced network bandwidth**: Minimizes egress costs and registry load
- **Improved scaling performance**: Enables rapid horizontal pod autoscaling during traffic spikes
- **Enhanced reliability**: Reduces dependency on external registry availability
- **Better resource utilization**: Allows nodes to spend more time running workloads rather than downloading images

## Why ephemeral NVMe data disks excel for image cache

Ephemeral NVMe data disks provide several advantages over traditional remote storage for container image caching:

### High-performance characteristics
- **Ultra-low latency**: NVMe disks provide sub-millisecond access times, dramatically speeding up image layer extraction and decompression
- **High IOPS**: Up to 400,000+ IOPS per disk enables concurrent image operations without performance degradation
- **High throughput**: Multi-GB/s bandwidth supports rapid transfer of large image layers
- **Consistent performance**: Unlike remote disks that may experience network-induced latency variations, local NVMe delivers predictable performance

### Cost optimization
- **No additional storage costs**: Ephemeral NVMe storage is included with VM pricing
- **Reduced network egress**: Local caching minimizes data transfer costs from container registries
- **Efficient resource utilization**: Better price-performance ratio compared to premium remote storage

### Operational benefits
- **Zero configuration overhead**: No need to manage persistent volumes or storage accounts for cache
- **Automatic cleanup**: Cache space is automatically reclaimed when nodes are recycled
- **Simplified architecture**: Eliminates complexity of shared storage solutions

## Configure containerd to use NVMe storage

The most effective approach is to configure the containerd runtime to use NVMe-backed storage for its root directory, which includes the image cache.

1. Stop your workload.

2. Create a node pool with NVMe-capable VMs:

```bash
# Variables
resourceGroup="myResourceGroup"
clusterName="myAKSCluster"
nodePoolName="nvme-nodes"
vmSize="Standard_L16s_v3"  # 4 NVMe disks, 1.8 TB total

# Create node pool with NVMe-capable VMs
az aks nodepool add \
    --resource-group $resourceGroup \
    --cluster-name $clusterName \
    --name $nodePoolName \
    --node-count 2 \
    --node-vm-size $vmSize
```

3. Configure containerd to use NVMe storage via DaemonSet:

> [!WARNING]
> This approach is not officially supported by AKS and may break with future updates. Review and use with caution and test thoroughly before deploying in production environments.

Download Daemonset sample:
```bash
curl -o containerd-nvme-daemonset.yaml https://github.com/Azure-Samples/azure-container-storage-samples/containerd/containerd-nvme-daemonset.yaml
```

Review and make changes as needed.

Create a DaemonSet to mount NVMe storage and configure containerd:
```bash
kubectl apply -f containerd-nvme-daemonset.yaml
```

4. Restart the node pool:
```bash
NODE_RESOURCE_GROUP=$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query nodeResourceGroup -o tsv)

VMSS_NAME=$(az vmss list --resource-group $NODE_RESOURCE_GROUP --query "[?contains(name, '${NODE_POOL}')].name" -o tsv)

az vmss restart --name $VMSS_NAME --resource-group $NODE_RESOURCE_GROUP --instance-ids '*'
```

5. Monitor DaemonSet deployment and status:

After applying the DaemonSet, monitor its status to ensure proper deployment.

Check DaemonSet status:
```bash
kubectl get daemonset -n kube-system containerd-nvme-config

# DaemonSet should show DESIRED = CURRENT = READY
NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
containerd-nvme-config   2         2         2       2            2           <none>          5m

# View detailed DaemonSet information if needed:
kubectl describe daemonset -n kube-system containerd-nvme-config
```

Check pods status on each node:
```bash
kubectl get pods -n kube-system -l name=containerd-nvme-config -o wide

NAME                           READY   STATUS    RESTARTS   AGE   IP           NODE
containerd-nvme-config-abc123  1/1     Running   0          5m    10.244.1.5   aks-nvme-node-1
containerd-nvme-config-def456  1/1     Running   0          5m    10.244.2.8   aks-nvme-node-2
```

View logs from a specific pod:
```bash
kubectl logs -n kube-system -l name=containerd-nvme-config --tail=50
```

Check if RAID setup completed successfully on a specific node:
```bash
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l name=containerd-nvme-config -o jsonpath='{.items[0].metadata.name}') -- chroot /host df -h /mnt/nvme-raid/containerd

Filesystem      Size  Used Avail Use% Mounted on
/dev/md0        3.5T  2.6G  3.3T   1% /mnt/nvme-raid/containerd
```

Verify containerd is using NVMe storage:
```bash
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l name=containerd-nvme-config -o jsonpath='{.items[0].metadata.name}') -- chroot /host crictl info | grep -i containerdRootDir

    "containerdRootDir": "/mnt/nvme-raid/containerd",
```

Check if containerd places images in the path:
```bash
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l name=containerd-nvme-config -o jsonpath='{.items[0].metadata.name}') -- chroot /host ls /mnt/nvme-raid/containerd

io.containerd.content.v1.content
io.containerd.grpc.v1.cri
io.containerd.grpc.v1.introspection
io.containerd.metadata.v1.bolt
io.containerd.runtime.v1.linux
io.containerd.runtime.v2.task
io.containerd.snapshotter.v1.blockfile
io.containerd.snapshotter.v1.btrfs
io.containerd.snapshotter.v1.native
io.containerd.snapshotter.v1.overlayfs
```

Check systemd service status:
```bash
kubectl exec -n kube-system $(kubectl get pods -n kube-system -l name=containerd-nvme-config -o jsonpath='{.items[0].metadata.name}') -- chroot /host systemctl status setup-raid.service

     Loaded: loaded (/etc/systemd/system/setup-raid.service; enabled; vendor preset: enabled)
     Active: active (exited) since Tue 2025-10-28 03:24:38 UTC; 1 day 23h ago
   Main PID: 861 (code=exited, status=0/SUCCESS)
        CPU: 1.082s
```
