#!/bin/bash

echo "🚀 Starting EKS Monitoring Stack Setup..."

# Phase 1: Infrastructure
echo "📦 Applying Terraform..."
cd ~/group3-sre/terraform
terraform apply -auto-approve
cd ~/group3-sre/monitoring_cluster

# Update kubeconfig
aws eks update-kubeconfig --name group3-cluster --region ap-southeast-1

# Install OpenLens service account
echo "💬 Adding OpenLens access..."
kubectl apply -f ~/group3-sre/monitoring_cluster/openlens.yaml
kubectl -n kube-system get secret openlens-access-token -o jsonpath="{.data.token}" | base64 --decode

# Phase 2: Setup EKS Observability
# Add Helm repos
echo "📋 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# Install Prometheus Stack
echo "📊 Installing Prometheus Stack..."
helm upgrade --install kube-prometheus-stack \
  --create-namespace \
  --namespace kube-prometheus-stack \
  -f ~/group3-sre/monitoring_cluster/alertmanager-config.yaml \
  prometheus-community/kube-prometheus-stack

# Retrieving Grafana 'admin' user password
echo "🔑 Retrieving Grafana 'admin' user password..."
kubectl --namespace kube-prometheus-stack get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Install Discord Bridge
echo "💬 Installing Discord Bridge..."
kubectl apply -f ~/group3-sre/monitoring_cluster/discord-bridge.yaml

# Phase 3: Database Setup
echo "🗄️ Installing MySQL HA Database Cluster..."

# Install EBS CSI driver addon (if not already done)
echo "💾 Installing EBS CSI driver..."
aws eks create-addon --cluster-name group3-cluster --addon-name aws-ebs-csi-driver --region ap-southeast-1 2>/dev/null || true

# Apply StorageClass
echo "💾 Creating StorageClass..."
kubectl apply -f ~/group3-sre/database_cluster/ebs-storageclass.yaml 2>/dev/null || echo "StorageClass already exists"

# Create namespace
echo "📦 Creating namespace..."
kubectl create namespace database-cluster --dry-run=client -o yaml | kubectl apply -f -

# Apply secrets
echo "🔐 Creating MySQL secrets..."
kubectl apply -f ~/group3-sre/database_cluster/secrets.yaml

# Install MySQL HA using Bitnami chart
echo "📊 Installing MySQL with HA (1 primary + 2 replicas)..."
if helm list -n database-cluster | grep -q my-release; then
  echo "MySQL already installed, skipping..."
else
  helm install my-release \
    --namespace database-cluster \
    -f ~/group3-sre/database_cluster/mysql-values.yaml \
    oci://registry-1.docker.io/bitnamicharts/mysql
fi

echo "✅ MySQL HA installation completed!"
echo "📊 MySQL metrics will be monitored by Prometheus"
echo "🔐 Credentials stored securely in Kubernetes secrets"
echo "Connection: my-release-mysql-primary.database-cluster.svc.cluster.local:3306"

# Phase 4: WordPress Application Setup
echo "🔍 Installing WordPress Application..."

# Create application namespace
echo "📦 Creating application namespace..."
kubectl create namespace application-cluster --dry-run=client -o yaml | kubectl apply -f -

# Deploy WordPress
echo "🔍 Deploying WordPress..."
kubectl apply -f ~/group3-sre/application_cluster/wordpress.yaml -n application-cluster

# Wait for WordPress pods to be ready
echo "⏳ Waiting for WordPress pods to be ready..."
kubectl wait --for=condition=ready pod -l app=wordpress -n application-cluster --timeout=300s

echo "✅ WordPress installation completed!"
echo "🌐 WordPress will be accessible via LoadBalancer"

# Get LoadBalancer endpoint
echo "⏳ Waiting for LoadBalancer to get external IP..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/wordpress -n application-cluster --timeout=300s
WORDPRESS_URL=$(kubectl get svc wordpress -n application-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -n "$WORDPRESS_URL" ]; then
  echo "🎉 WordPress available at: http://$WORDPRESS_URL"
else
  echo "⚠️ LoadBalancer IP not ready yet. Check with: kubectl get svc wordpress -n application-cluster"
fi

# Phase 5: Port Forwarding for UI Access
echo "🌐 Cleaning up existing port forwards..."
pkill -f "kubectl.*port-forward" 2>/dev/null || true
sleep 2

echo "🌐 Setting up port forwarding for UI access..."
echo "📊 Grafana UI: http://localhost:8080"
kubectl --namespace kube-prometheus-stack port-forward svc/kube-prometheus-stack-grafana 8080:80 &

echo "📈 Prometheus UI: http://localhost:8081"
kubectl --namespace kube-prometheus-stack port-forward svc/kube-prometheus-stack-prometheus 8081:9090 &

echo "🚨 Alertmanager UI: http://localhost:8082"
kubectl --namespace kube-prometheus-stack port-forward svc/kube-prometheus-stack-alertmanager 8082:9093 &

echo "✅ All services are now accessible via port forwarding!"
echo "Press Ctrl+C to stop all port forwards"