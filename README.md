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
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | head -5
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
      key: trusted_ips
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

## 🔍 Monitoring

```bash
# Check CronJob status
kubectl get cronjob bunny-ip-updater

# View recent job logs
kubectl logs -l job-name=bunny-ip-updater --tail=50

# Check IP count
kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | wc -l
```

## 📁 Repository Structure

```
├── bunny-ip-updater.yaml    # Main Kubernetes manifests
├── examples/                # Integration examples
├── scripts/                 # Setup and utility scripts
└── README.md               # This file
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
