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
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.TRUSTED_PROXY_IP}' | tr ',' '\n' | wc -l

# View sample IPs
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.TRUSTED_PROXY_IP}' | tr ',' '\n' | head -5

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
- Namespace-scoped RBAC with minimal required permissions:
  - ConfigMap access: get, list, create, update, patch for `bunny-trusted-ips`
  - ConfigMap read access: get, list for Mastodon environment ConfigMaps
  - Deployment access: get, list, patch for Mastodon deployments (restart capability)
- Root containers with writable filesystem (required for package installation)
- Resource limits and security contexts enforced
- No privileged access or capability escalation

### Data Flow
1. CronJob fetches IPv4 addresses from `https://bunnycdn.com/api/system/edgeserverlist`
2. Fetches IPv6 addresses from `https://bunnycdn.com/api/system/edgeserverlist/ipv6`
3. Extracts custom trusted IPs from Mastodon environment ConfigMap (if present)
4. Combines default ranges, custom IPs, and Bunny CDN IPs as comma-separated list
5. Updates ConfigMap with `kubectl patch`
6. Automatically restarts Mastodon deployments to pick up new environment variables
7. Applications consume updated trusted proxy configuration

### Integration Patterns
Applications can consume the IP list through:
- **Mastodon Integration**: Environment variable `TRUSTED_PROXY_IP` from ConfigMap key `TRUSTED_PROXY_IP`
- **Basic Integration**: Environment variable from ConfigMap key `trusted_ips` (deprecated)
- **File mount**: Mount ConfigMap as volume for custom processing
- **Init container**: Process IPs into application-specific format (see examples)

## File Structure

- `bunny-ip-updater.yaml`: Complete Kubernetes manifests (ConfigMap, RBAC, CronJob)
- `scripts/setup.sh`: Interactive deployment script with verification
- `scripts/monitor.sh`: Multi-function monitoring and management script
- `examples/app-deployment.yaml`: Shows environment variable and file mount patterns
- `examples/nginx-config.yaml`: Advanced init container pattern for Nginx configuration

## Mastodon Integration

For Mastodon deployments, use the specialized integration manifest:

```bash
# Deploy Bunny IP updater for Mastodon
kubectl apply -f examples/mastodon-integration.yaml

# Configure Mastodon Helm values to reference the ConfigMap
# See examples/mastodon-values.yaml
# 
# Note: The Mastodon integration automatically restarts deployments 
# after ConfigMap updates to ensure pods pick up new environment variables
```

## Monitoring and Troubleshooting

The system is designed to be observable through standard Kubernetes tools:
- CronJob status indicates scheduling health
- Job completion/failure shows execution status
- ConfigMap resource version tracks update currency
- Pod logs contain detailed execution information with emojis for easy parsing

Failed jobs are retained (limit: 3) for troubleshooting, and the monitoring script can compare ConfigMap contents with live API data to detect staleness.

### Common Issues

**Job crashes during package installation**:
- `jq: command not found`: Fixed by improving package installation error handling and visibility
- `stream closed EOF`: Can be caused by kubectl installation failure from Alpine package manager
- Fixed by installing kubectl from official Kubernetes release API and adding proper error handling for jq/curl installation
- Check job logs: `kubectl logs -l job-name=bunny-ip-updater --tail=50`

**ConfigMap not updating**:
- Check RBAC permissions: `kubectl auth can-i update configmaps --as=system:serviceaccount:default:bunny-ip-updater`
- Verify CronJob schedule and recent job runs
- Manual trigger: `kubectl create job bunny-ip-manual-$(date +%s) --from=cronjob/bunny-ip-updater`

## Development Workflow

### Testing Changes
```bash
# Test the CronJob logic manually
kubectl create job bunny-ip-test-$(date +%s) --from=cronjob/bunny-ip-updater

# Follow job execution in real-time
kubectl logs -f job/bunny-ip-test-<timestamp>

# Validate ConfigMap contents after test
./scripts/monitor.sh compare
```

### Script Development
- `scripts/setup.sh`: Interactive deployment with validation
- `scripts/monitor.sh`: Comprehensive monitoring with subcommands (status|compare|logs|trigger|all)
- Both scripts use colored output and proper error handling
- Scripts should be run from project root directory

### YAML Manifest Structure
The main `bunny-ip-updater.yaml` contains:
1. ConfigMap: Initial empty data for storing IP addresses
2. RBAC: ServiceAccount + Role + RoleBinding with least privilege
3. CronJob: Alpine-based container with curl and kubectl

### Security Considerations
- Root containers with writable filesystem (required for package installation)
- Resource limits prevent resource exhaustion
- RBAC restricts access to necessary resources only
- No privileged access or capability escalation
- Minimal attack surface with Alpine base image