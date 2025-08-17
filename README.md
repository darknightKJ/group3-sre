# group3-sre

## Introduction

This repo is used host the code for final project of group 3.

## Usage

Fork the repoitory, run setup-observability.sh in to automate the provisioning of VPC, EKS cluster, monitoring setup.

The setup-observability.sh script is a complete infrastructure setup that includes:

-Phase 1: Terraform infrastructure
-Phase 2: Prometheus monitoring stack + Discord alerts
-Phase 3: MySQL HA database cluster (with replication)
-Phase 4: WordPress Application Setup (LoadBalancer service)
-Phase 5: Port forwarding for UI access

This provides end-to-end setup from infrastructure to applications in one script. The MySQL installation includes proper secret management and HA configuration.

## Service Status Checks

Refer to `SERVICE_CHECK_GUIDE.md` for comprehensive instructions on checking all running services and troubleshooting.

To trigger test alert with custom message - open new terminal, cd monitoring_cluster folder, run:
`curl -XPOST http://localhost:8082/api/v2/alerts -H "Content-Type: application/json" -d @test-alert.json`

## Database Connection

MySQL Primary: `my-release-mysql-primary.database-cluster.svc.cluster.local:3306`

## Teardown

To completely destroy all infrastructure and applications:

```bash
./teardown.sh
```

This will:
- Stop all port forwards
- Delete all Kubernetes applications and namespaces
- Remove persistent volumes
- Destroy all Terraform infrastructure
- Clean up state files

**⚠️ Warning: This is irreversible and will delete all data!**
