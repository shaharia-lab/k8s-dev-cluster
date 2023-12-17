# Local Kubernetes Cluster

This directory contains all the necessary bash script and helm charts to create a local kubernetes
cluster by using `Kind`

## Installation

### Create Kind Cluster

```bash
chmod +x ./create_cluster.sh
./create_cluster.sh
```

### Get Kubeconfig

```bash
➜ kind get kubeconfig --name local-k8s > ~/.kube/config
```

If you want to access the cluster from another machine, you need to change your kubeconfig file a little bit:

```yaml
clusters:
  - name: kind-local-k8s
    cluster:
      # need to remove "certificate-authority-data" otherwise "insecure-skip-tls-verify" will not work
      server: https://x.x.x.x:6443 # change this to your IP address where "Kind" cluster is running
      insecure-skip-tls-verify: true # add this
```

### Install Necessary Tools using Helmfile

```bash
### Install Helm charts

```bash
helmfile --file ./helm deps
helmfile --file ./helm sync
```