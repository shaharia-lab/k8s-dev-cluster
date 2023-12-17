#!/bin/bash

# Set the desired configuration
KIND_VERSION="v0.20.0"
CLUSTER_NAME="local-k8s"
KUBERNETES_VERSION="v1.22.0"
NODES=2

# Function to delete an existing Kind cluster
delete_cluster() {
    local cluster_name=$1
    if kind get clusters | grep -q "^$cluster_name$"; then
        echo "Kind cluster '$cluster_name' is already running. Deleting the cluster..."
        kind delete cluster --name "$cluster_name"
    fi
}

# Function to install Kind if not already installed
install_kind() {
    if ! command -v kind &> /dev/null; then
        echo "Kind not found. Installing Kind..."
        curl -Lo ./kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64"
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
}

# Function to create the Kind cluster
create_cluster() {
    local cluster_name=$1
    local nodes=$2
    echo "Creating Kind cluster: $cluster_name with $nodes nodes..."
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

# Function to set kubeconfig context
set_kubeconfig_context() {
    local cluster_name=$1
    export KUBECONFIG="$(kind get kubeconfig-path --name="$cluster_name")"
}

# Function to verify cluster status
verify_cluster_status() {
    echo "Verifying cluster status..."
    kubectl cluster-info
}

# Function to wait until all nodes are ready
wait_for_nodes_ready() {
    echo "Waiting for all nodes to be ready..."
    kubectl wait --for=condition=ready nodes --all --timeout=300s
}

# Function to install and configure Ingress controller
install_ingress_controller() {
    echo "Installing ingress controller"
    kubectl create ns ingress-nginx
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml -n ingress-nginx
}

# Function to wait until Ingress controller is ready
wait_for_ingress_ready() {
    echo "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s
}

# Function to deploy test app
deploy_test_app() {
    echo "Deploying test app..."
    kubectl create deployment test-app --image=nginx
    kubectl expose deployment test-app --type=NodePort --port=80 --target-port=80
    echo "Test app deployed and exposed."
}

# Function to print URL for accessing the test app
print_test_app_url() {
    local cluster_ip
    cluster_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    local node_port
    node_port=$(kubectl get service test-app -o jsonpath='{.spec.ports[0].nodePort}')
    echo "You can access the test app at: http://$cluster_ip:$node_port"
}

# Function to install PostgreSQL in Kind cluster using Helm chart
install_postgresql() {
    local chart_name="postgresql"
    local chart_repo="https://charts.bitnami.com/bitnami"
    local namespace="$1"
    local release_name="postgresql"
    local admin_username="app"
    local admin_password="pass"
    local admin_database="app"

    echo "Installing PostgreSQL using Helm chart..."

    # Add the Bitnami Helm repository
    helm repo add bitnami "$chart_repo"

    # Create the PostgreSQL namespace
    kubectl create namespace "$namespace"

    # Install PostgreSQL using the Helm chart and override admin credentials
    helm upgrade --install "$release_name" bitnami/"$chart_name" \
        --namespace "$namespace" \
        --set auth.username="$admin_username" \
        --set auth.password="$admin_password" \
        --set auth.database="$admin_database"

    echo "PostgreSQL installation completed."
}

# Function to deploy kube-prometheus-stack Helm chart to Kind cluster
# Function to deploy kube-prometheus-stack Helm chart to Kind cluster
deploy_kube_prometheus_stack() {
    local cluster_name=$1
    local chart_name="kube-prometheus-stack"
    local chart_repo="https://prometheus-community.github.io/helm-charts"
    local namespace="$2"
    local release_name="kube-prometheus"

    echo "Deploying kube-prometheus-stack Helm chart..."

    # Add the Prometheus Community Helm repository
    helm repo add prometheus-community "$chart_repo"

    # Create the namespace if it doesn't exist
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Install the kube-prometheus-stack chart with desired configurations
    helm upgrade --install "$release_name" prometheus-community/"$chart_name" \
        --namespace "$namespace" \
        --kubeconfig $KUBECONFIG \
        --set prometheus.enabled="true" \
        --set prometheus.serviceAccount.name="kube-prometheus" \
        --set prometheus.ingress.annotations."kubernetes\.io/ingress\.class"="nginx" \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues="false" \
        --set prometheus.prometheusSpec.serviceMonitorSelector.matchExpressions[0].key="prometheus" \
        --set prometheus.prometheusSpec.serviceMonitorSelector.matchExpressions[0].operator="In" \
        --set prometheus.prometheusSpec.serviceMonitorSelector.matchExpressions[0].values[0]="kube-prometheus" \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues="false" \
        --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues="false"

    echo "kube-prometheus-stack deployment completed."
}



# Main script

# Function to prepare the Kind cluster
prepare_kind_cluster() {
    local cluster_name=$1
    local nodes=$2

    # Delete existing Kind cluster if running
    delete_cluster "$cluster_name"

    # Install Kind if not already installed
    install_kind

    # Create the Kind cluster
    create_cluster "$cluster_name" "$nodes"

    # Set kubeconfig context
    ##set_kubeconfig_context "$cluster_name"

    # Verify cluster status
    verify_cluster_status

    # Wait until all nodes are ready
    wait_for_nodes_ready
}

prepare_kind_cluster $CLUSTER_NAME $NODES