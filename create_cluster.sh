#!/bin/bash

# Define the version of Kind to be used, the name of the cluster to be created, and the number of nodes in the cluster
KIND_VERSION="v0.20.0"
CLUSTER_NAME="local-k8s"
NODES=3

# Function to delete the Kind cluster if it is already running
delete_cluster() {
    local cluster_name=$1

    # Check if the cluster is already running
    if kind get clusters | grep -q "^$cluster_name$"; then
        echo "Kind cluster '$cluster_name' is already running. Deleting the cluster..."

        # Delete the running cluster
        kind delete cluster --name "$cluster_name"
    fi
}

# Function to install Kind if it is not already installed
install_kind() {
    # Check if Kind is installed
    if ! command -v kind &> /dev/null; then
        echo "Kind not found. Installing Kind..."

        # Download Kind from the official repository
        curl -Lo ./kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64"

        # Make the downloaded file executable
        chmod +x ./kind

        # Move the executable file to the local bin directory
        sudo mv ./kind /usr/local/bin/kind
    fi
}

# Function to create the Kind cluster
create_cluster() {
    local cluster_name=$1
    local nodes=$2
    echo "Creating Kind cluster: $cluster_name with $nodes nodes..."

    # Create the cluster with the specified configuration
    cat <<EOF | kind create cluster --name "$cluster_name" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
kubeadmConfigPatches:
- |-
  kind: ClusterConfiguration
  # configure controller-manager bind address
  controllerManager:
    extraArgs:
      bind-address: 0.0.0.0
  # configure etcd metrics listen address
  etcd:
    local:
      extraArgs:
        listen-metrics-urls: http://0.0.0.0:2381
  # configure scheduler bind address
  scheduler:
    extraArgs:
      bind-address: 0.0.0.0
- |-
  kind: KubeProxyConfiguration
  # configure proxy metrics bind address
  metricsBindAddress: 0.0.0.0
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 443
    hostPort: 443
    protocol: TCP
    listenAddress: "0.0.0.0"
EOF
}

# Function to verify the status of the cluster
verify_cluster_status() {
    echo "Verifying cluster status..."

    # Print the cluster information
    kubectl cluster-info
}

# Function to wait until all nodes in the cluster are ready
wait_for_nodes_ready() {
    echo "Waiting for all nodes to be ready..."

    # Wait until all nodes are ready
    kubectl wait --for=condition=ready nodes --all --timeout=300s
}

# Function to print the IP address of the control panel of the Kind cluster
print_kind_cluster_control_panel_ip() {
  local cluster_name=$1

  # Get the name of the control plane node
  node_name=$(kubectl get nodes --selector=node-role.kubernetes.io/control-plane= -o jsonpath='{.items[0].metadata.name}')

  # Get the internal IP address of the control plane node
  internal_ip=$(kubectl get nodes "${node_name}" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

  # Print the internal IP address
  echo "IP Address for KiND cluster control plane: ${cluster_name}: ${internal_ip}"
}

# Main script

# Function to prepare the Kind cluster
prepare_kind_cluster() {
    local cluster_name=$1
    local nodes=$2

    # Delete the existing Kind cluster if it is running
    delete_cluster "$cluster_name"

    # Install Kind if it is not already installed
    install_kind

    # Create the Kind cluster
    create_cluster "$cluster_name" "$nodes"

    # Verify the status of the cluster
    verify_cluster_status

    # Wait until all nodes in the cluster are ready
    wait_for_nodes_ready

    # Print the IP address of the control panel of the Kind cluster
    print_kind_cluster_control_panel_ip "$cluster_name"
}

# Call the function to prepare the Kind cluster
prepare_kind_cluster $CLUSTER_NAME $NODES