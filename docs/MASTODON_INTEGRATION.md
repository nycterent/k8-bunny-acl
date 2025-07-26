# Mastodon Integration Guide

This guide explains how to integrate the Bunny CDN IP updater with the [Mastodon Helm chart](https://github.com/mastodon/chart) to automatically configure trusted proxy IPs for proper client IP detection.

## Overview

The Mastodon Helm chart supports configuring trusted proxy IPs through the `TRUSTED_PROXY_IP` environment variable. Our Bunny CDN IP updater provides this exact data format (comma-separated IP list) via a ConfigMap that updates daily.

## Prerequisites

- Kubernetes cluster with Helm 3.8.0+
- kubectl access to the cluster
- Mastodon Helm chart repository added: `helm repo add mastodon https://mastodon.github.io/chart`

## Deployment Steps

### 1. Deploy Bunny IP Updater

Deploy the IP updater in the same namespace where Mastodon will be installed:

```bash
# Create mastodon namespace
kubectl create namespace mastodon

# Deploy the Bunny IP updater
kubectl apply -f examples/mastodon-integration.yaml
```

### 2. Verify IP Updater Setup

```bash
# Check that the CronJob is created
kubectl get cronjob bunny-ip-updater -n mastodon

# Trigger initial IP fetch
kubectl create job bunny-ip-manual-initial --from=cronjob/bunny-ip-updater -n mastodon

# Wait for job completion and verify ConfigMap
kubectl wait --for=condition=complete --timeout=300s job/bunny-ip-manual-initial -n mastodon
kubectl get configmap bunny-trusted-ips -n mastodon -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | wc -l

# Cleanup manual job
kubectl delete job bunny-ip-manual-initial -n mastodon
```

### 3. Configure Mastodon Values

Use the provided `examples/mastodon-values.yaml` as a starting point and customize for your environment:

```bash
# Copy and edit the values file
cp examples/mastodon-values.yaml my-mastodon-values.yaml

# Edit with your domain, SMTP, S3, and other settings
# The trusted proxy configuration is already set up to use the Bunny CDN IPs
```

### 4. Deploy Mastodon

```bash
# Add Mastodon Helm repository
helm repo add mastodon https://mastodon.github.io/chart
helm repo update

# Deploy Mastodon with the configured values
helm install mastodon mastodon/mastodon \
  --namespace mastodon \
  --values my-mastodon-values.yaml \
  --wait
```

## Configuration Details

### Trusted Proxy Configuration

The integration works through these key configurations in the Mastodon values:

```yaml
mastodon:
  extraEnvVars:
    - name: TRUSTED_PROXY_IP
      valueFrom:
        configMapKeyRef:
          name: bunny-trusted-ips
          key: trusted_ips
          optional: false
```

This configuration:
- References the `bunny-trusted-ips` ConfigMap created by our CronJob
- Automatically updates when the CronJob runs (daily at 2 AM UTC)  
- Provides the comma-separated IP list format expected by Mastodon

### Ingress Considerations

When using Bunny CDN, configure your ingress with real IP forwarding:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
    nginx.ingress.kubernetes.io/enable-real-ip: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "40m"
```

### WebSocket Streaming

For Mastodon's streaming API (WebSockets), ensure your CDN configuration supports:
- WebSocket upgrades
- Long-lived connections
- Proper forwarding of upgrade headers

## Monitoring and Maintenance

### Check IP Update Status

```bash
# Check CronJob status
kubectl get cronjob bunny-ip-updater -n mastodon

# View recent job logs
kubectl logs -l job-name=bunny-ip-updater -n mastodon --tail=50

# Compare ConfigMap with live API
./scripts/monitor.sh compare
```

### Verify Mastodon Configuration

```bash
# Check that Mastodon pods have the trusted proxy environment variable
kubectl get pods -l app.kubernetes.io/name=mastodon -n mastodon -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="TRUSTED_PROXY_IP")]}' | jq

# Verify the IP count matches
kubectl exec -n mastodon deployment/mastodon-web -- env | grep TRUSTED_PROXY_IP | tr ',' '\n' | wc -l
```

### Manual IP Update

If you need to trigger an immediate update:

```bash
# Trigger manual update
kubectl create job bunny-ip-manual-$(date +%s) --from=cronjob/bunny-ip-updater -n mastodon

# Or use the monitoring script
./scripts/monitor.sh trigger
```

## Troubleshooting

### ConfigMap Not Updating

1. Check CronJob status: `kubectl describe cronjob bunny-ip-updater -n mastodon`
2. Check recent job logs: `kubectl logs -l job-name=bunny-ip-updater -n mastodon`
3. Verify RBAC permissions: `kubectl auth can-i update configmaps --as=system:serviceaccount:mastodon:bunny-ip-updater -n mastodon`

### Mastodon Not Using Updated IPs

1. Check environment variable: `kubectl exec -n mastodon deployment/mastodon-web -- env | grep TRUSTED_PROXY_IP`
2. Restart Mastodon pods to pick up ConfigMap changes: `kubectl rollout restart deployment/mastodon-web -n mastodon`
3. Verify ingress real IP configuration

### IP Count Mismatch

Use the monitoring script to compare ConfigMap with live API:
```bash
./scripts/monitor.sh compare
```

If there's a mismatch, trigger a manual update and check the job logs for errors.

## Security Considerations

- The Bunny IP updater uses namespace-scoped RBAC with minimal permissions
- Only the specific `bunny-trusted-ips` ConfigMap can be modified
- Container runs as non-root with read-only filesystem
- Resource limits prevent resource exhaustion
- Failed jobs are retained for troubleshooting but cleaned up automatically

## CDN Configuration Notes

When configuring Bunny CDN for Mastodon:

1. **Real IP Forwarding**: Ensure `X-Forwarded-For` and `X-Real-IP` headers are forwarded
2. **WebSocket Support**: Enable WebSocket upgrades for `/api/v1/streaming`
3. **File Upload**: Configure appropriate limits for media uploads (40MB default)
4. **Cache Settings**: Consider cache rules for static assets vs. dynamic content
5. **SSL/TLS**: Ensure end-to-end encryption between CDN and Kubernetes ingress

The automatic IP updates ensure that Mastodon will correctly identify client IPs even as Bunny CDN's edge server infrastructure evolves.