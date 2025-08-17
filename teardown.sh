#!/bin/bash

echo "🔥 Starting Complete Infrastructure Teardown..."

# Phase 1: Stop Port Forwards
echo "🛑 Stopping port forwards..."
pkill -f "kubectl.*port-forward" 2>/dev/null || true

# Phase 2: Delete Kubernetes Applications
echo "🗑️ Deleting WordPress application..."
kubectl delete namespace application-cluster --ignore-not-found=true

echo "🗑️ Deleting MySQL database..."
kubectl delete namespace database-cluster --ignore-not-found=true

echo "🗑️ Deleting monitoring stack..."
helm uninstall kube-prometheus-stack -n kube-prometheus-stack 2>/dev/null || true
kubectl delete namespace kube-prometheus-stack --ignore-not-found=true

# Phase 3: Delete Persistent Volumes
echo "💾 Deleting persistent volumes..."
kubectl delete pv --all --ignore-not-found=true

# Phase 4: Terraform Destroy
echo "💥 Destroying Terraform infrastructure..."
cd ~/group3-sre/terraform

# Force delete any stuck resources
terraform state list | grep -E "(aws_security_group|aws_lb)" | xargs -r terraform state rm 2>/dev/null || true

# Destroy infrastructure
terraform destroy -auto-approve

# Clean up terraform state
rm -f terraform.tfstate*
rm -rf .terraform/

echo "✅ Teardown completed!"
echo "🧹 All resources have been destroyed"
echo ""
echo "Verify cleanup:"
echo "- Check AWS Console for any remaining resources"
echo "- Run: kubectl get nodes (should show no resources)"
echo "- Run: aws eks list-clusters --region ap-southeast-1"