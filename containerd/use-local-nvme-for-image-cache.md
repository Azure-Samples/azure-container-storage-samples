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

1. Create a node pool with NVMe-capable VMs:

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

2. Configure containerd to use NVMe storage via DaemonSet:

Download Daemonset sample and make changes as need:
```bash
curl -o containerd-nvme-daemonset.yaml https://github.com/Azure-Samples/azure-container-storage-samples/containerd/containerd-nvme-daemonset.yaml
```

Create a DaemonSet to mount NVMe storage and configure containerd:
```bash
kubectl apply -f containerd-nvme-daemonset.yaml
```
