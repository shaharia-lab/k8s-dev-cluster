# k8s-dev-cluster

Deploy a local kubernetes cluster for development purpose. This repository contains all the necessary tools to create a local kubernetes cluster using `Kind` and `Helmfile`

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [Helmfile](https://github.com/roboll/helmfile)

## Usage

### Create Cluster

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
helmfile --file ./helm deps
helmfile --file ./helm sync
```

After that, you can access the cluster using `kubectl`:

```bash
➜ kubectl get nodes                                                                            
NAME                      STATUS   ROLES           AGE   VERSION
local-k8s-control-plane   Ready    control-plane   27m   v1.25.3
```

## Contributing

If you want to contribute to this repository, please create an issue first, then create a pull request with your changes. If the changes can help other developers, we can proceed with the pull request.

## Create Issue

If you have any questions or issues, please create an issue [here](https://github.com/shaharia-lab/k8s-dev-cluster/issues)

## Disclaimer

This repository is only for development purpose. Do not use it in production.