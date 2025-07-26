# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes-based security tool that automatically fetches and manages Bunny CDN edge server IP addresses for trusted proxy configurations. The system operates as a CronJob that updates a ConfigMap daily with current IP addresses, which applications can consume for security configurations.

## Key Commands

### Deployment and Setup
```bash
# Deploy the complete system
kubectl apply -f bunny-ip-updater.yaml

# Setup with interactive confirmation
./scripts/setup.sh

# Monitor system status
./scripts/monitor.sh status

# Compare ConfigMap with live API data
./scripts/monitor.sh compare

# Trigger manual update
./scripts/monitor.sh trigger

# View recent job logs
./scripts/monitor.sh logs
```

### Verification Commands
```bash
# Check CronJob status
kubectl get cronjob bunny-ip-updater

# Verify ConfigMap population
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | wc -l

# View sample IPs
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | head -5

# Check recent job runs
kubectl get jobs -l job-name=bunny-ip-updater --sort-by=.metadata.creationTimestamp

# View job logs
kubectl logs -l job-name=bunny-ip-updater --tail=50
```

## Architecture

### Core Components
- **CronJob**: `bunny-ip-updater` runs daily at 2 AM UTC
- **ConfigMap**: `bunny-trusted-ips` stores comma-separated IP list
- **RBAC**: ServiceAccount, Role, and RoleBinding with minimal permissions
- **Job Container**: Uses `alpine/curl:latest` with security hardening

### Security Model
- Namespace-scoped RBAC with resource-specific access to only the `bunny-trusted-ips` ConfigMap
- Non-root containers (user 65534) with read-only filesystem
- Resource limits and security contexts enforced
- No privileged access or capability escalation

### Data Flow
1. CronJob fetches IPv4 addresses from `https://bunnycdn.com/api/system/edgeserverlist`
2. Fetches IPv6 addresses from `https://bunnycdn.com/api/system/edgeserverlist/ipv6`
3. Combines and formats as comma-separated list
4. Updates ConfigMap with `kubectl patch`
5. Applications consume via environment variables or file mounts

### Integration Patterns
Applications can consume the IP list through:
- Environment variable: `TRUSTED_PROXY_IPS` from ConfigMap key `trusted_ips`
- File mount: Mount ConfigMap as volume at `/etc/trusted-ips/trusted_ips.txt`
- Init container: Process IPs into application-specific format (see `examples/nginx-config.yaml`)

## File Structure

- `bunny-ip-updater.yaml`: Complete Kubernetes manifests (ConfigMap, RBAC, CronJob)
- `scripts/setup.sh`: Interactive deployment script with verification
- `scripts/monitor.sh`: Multi-function monitoring and management script
- `examples/app-deployment.yaml`: Shows environment variable and file mount patterns
- `examples/nginx-config.yaml`: Advanced init container pattern for Nginx configuration

## Monitoring and Troubleshooting

The system is designed to be observable through standard Kubernetes tools:
- CronJob status indicates scheduling health
- Job completion/failure shows execution status
- ConfigMap resource version tracks update currency
- Pod logs contain detailed execution information with emojis for easy parsing

Failed jobs are retained (limit: 3) for troubleshooting, and the monitoring script can compare ConfigMap contents with live API data to detect staleness.