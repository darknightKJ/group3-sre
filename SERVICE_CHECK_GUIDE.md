# Service Status Check Guide

## Check All Running Services

### 1. Kubernetes Pods Status
```bash
# Check all pods across namespaces
kubectl get pods --all-namespaces

# Check specific namespaces
kubectl get pods -n kube-prometheus-stack    # Monitoring stack
kubectl get pods -n database-cluster         # MySQL database
kubectl get pods -n application-cluster      # WordPress app
```

### 2. Services and Endpoints
```bash
# Check all services
kubectl get svc --all-namespaces

# Check LoadBalancer status
kubectl get svc -n application-cluster wordpress

# Check MySQL services
kubectl get svc -n database-cluster
```

### 3. Access URLs

#### Monitoring Stack (Port-forwarded)
```bash
# Check if port-forwards are running
ps aux | grep "kubectl.*port-forward"

# Access URLs (if port-forwards are active)
# http://localhost:8080 - Grafana
# http://localhost:8081 - Prometheus  
# http://localhost:8082 - Alertmanager
```

#### WordPress Application
```bash
# Get LoadBalancer URL
kubectl get svc wordpress -n application-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# If using NodePort, get node IP and port
kubectl get nodes -o wide
kubectl get svc wordpress -n application-cluster
```

### 4. Database Connectivity
```bash
# Connect to MySQL from within cluster
kubectl run mysql-client --rm -it --image=mysql:8.0 -n database-cluster -- mysql -h my-release-mysql-primary -u wpuser -p
# Password: wppassword

# Check MySQL pods status
kubectl get pods -n database-cluster -l app.kubernetes.io/name=mysql
```

### 5. Health Checks
```bash
# Check pod logs for issues
kubectl logs -n application-cluster -l app=wordpress
kubectl logs -n database-cluster -l app.kubernetes.io/name=mysql

# Check events for troubleshooting
kubectl get events -n application-cluster --sort-by='.lastTimestamp'
kubectl get events -n database-cluster --sort-by='.lastTimestamp'
```

### 6. Resource Usage
```bash
# Check resource consumption
kubectl top pods --all-namespaces
kubectl top nodes

# Check persistent volumes
kubectl get pv
kubectl get pvc --all-namespaces
```

## Quick Status Summary
```bash
# One-liner to check all critical services
echo "=== Monitoring Stack ===" && kubectl get pods -n kube-prometheus-stack && \
echo "=== Database Cluster ===" && kubectl get pods -n database-cluster && \
echo "=== WordPress App ===" && kubectl get pods -n application-cluster && \
echo "=== LoadBalancer ===" && kubectl get svc wordpress -n application-cluster
```