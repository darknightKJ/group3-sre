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
kubectl apply -f openlens.yaml
kubectl -n kube-system get secret openlens-access-token -o jsonpath="{.data.token}" | base64 --decode

# Phase 2: Setup Observability
# Add Helm repos
echo "📋 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# Install Prometheus Stack
echo "📊 Installing Prometheus Stack..."
helm upgrade --install kube-prometheus-stack \
  --create-namespace \
  --namespace kube-prometheus-stack \
  -f alertmanager-config.yaml \
  prometheus-community/kube-prometheus-stack

# Retrieving Grafana 'admin' user password
echo "🔑 Retrieving Grafana 'admin' user password..."
kubectl --namespace kube-prometheus-stack get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Install Discord Bridge
echo "💬 Installing Discord Bridge..."
kubectl apply -f discord-bridge.yaml

# Phase 3: Port Forwarding for UI Access
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