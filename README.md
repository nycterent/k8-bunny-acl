# Kubernetes Bunny CDN ACL Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.19+-blue.svg)](https://kubernetes.io/)
[![Security](https://img.shields.io/badge/Security-RBAC_Enabled-green.svg)](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

Automatically fetch and manage Bunny CDN edge server IP addresses in Kubernetes for trusted proxy configurations.

## 🚀 Quick Start

```bash
# Deploy to Kubernetes
kubectl apply -f bunny-ip-updater.yaml

# Verify deployment
kubectl get cronjob bunny-ip-updater
kubectl get configmap bunny-trusted-ips

# Check the IPs
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.TRUSTED_PROXY_IP}' | tr ',' '\n' | head -5
```

## 📖 Features

- ✅ **Automated Daily Updates**: CronJob runs daily at 2 AM UTC
- 🔒 **Secure RBAC**: Least privilege access with namespace-scoped permissions  
- 🌐 **IPv4 + IPv6 Support**: Fetches both IP address types from Bunny CDN
- 📊 **Monitoring Ready**: Comprehensive logging and status tracking
- 🚀 **Easy Integration**: Multiple consumption methods for applications
- 🛡️ **Security Hardened**: Non-root containers, read-only filesystem, resource limits

## 🔧 Usage in Applications

### Environment Variable
```yaml
env:
- name: TRUSTED_PROXY_IPS
  valueFrom:
    configMapKeyRef:
      name: bunny-trusted-ips
      key: TRUSTED_PROXY_IP
```

### File Mount
```yaml
volumeMounts:
- name: trusted-ips
  mountPath: /etc/trusted-ips
  readOnly: true
volumes:
- name: trusted-ips
  configMap:
    name: bunny-trusted-ips
```

## 🐘 Mastodon Integration

Special integration for [Mastodon Helm chart](https://github.com/mastodon/chart) with automatic trusted proxy configuration:

```bash
# Deploy Mastodon integration
kubectl apply -f examples/mastodon-integration.yaml

# Use provided Helm values
helm install mastodon mastodon/mastodon \
  --namespace mastodon \
  --values examples/mastodon-values.yaml
```

See [docs/MASTODON_INTEGRATION.md](docs/MASTODON_INTEGRATION.md) for complete setup guide.

## 🔍 Monitoring

```bash
# Check CronJob status
kubectl get cronjob bunny-ip-updater

# View recent job logs
kubectl logs -l job-name=bunny-ip-updater --tail=50

# Check IP count
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.TRUSTED_PROXY_IP}' | tr ',' '\n' | wc -l

# Use monitoring script for advanced checks
./scripts/monitor.sh status
./scripts/monitor.sh compare  # Compare with live API
```

## 📁 Repository Structure

```
├── bunny-ip-updater.yaml              # Main Kubernetes manifests
├── examples/                           # Integration examples
│   ├── app-deployment.yaml            # Basic application integration
│   ├── mastodon-integration.yaml      # Mastodon Helm chart integration
│   ├── mastodon-values.yaml           # Mastodon Helm values template
│   └── nginx-config.yaml              # Nginx configuration example
├── scripts/                            # Deployment and monitoring scripts
│   ├── setup.sh                       # Interactive deployment script
│   └── monitor.sh                     # Monitoring and management tools
├── docs/                              # Documentation
│   └── MASTODON_INTEGRATION.md        # Detailed Mastodon integration guide
├── .github/workflows/                 # CI/CD workflows
│   └── semgrep.yml                    # Security scanning
├── CLAUDE.md                          # AI assistant instructions
└── README.md                          # This file
```

## 🔒 Security

- **Namespace-scoped RBAC**: Only operates within deployment namespace
- **Resource-specific access**: Only the `bunny-trusted-ips` ConfigMap
- **Non-root containers**: Runs as user 65534 (nobody)
- **Read-only filesystem**: Prevents runtime modifications
- **Resource limits**: Memory, CPU, and storage limits enforced

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📞 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/nycterent/k8-bunny-acl/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/nycterent/k8-bunny-acl/discussions)
