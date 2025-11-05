# k8-bunny-acl Overview

This repository packages a Kubernetes CronJob that fetches the latest Bunny CDN edge IP ranges and republishes them as a ConfigMap, making it simple for applications to maintain an accurate `TRUSTED_PROXY_IP` list. The manifests are tuned for secure, namespace-scoped operation with RBAC, resource limits, and support for both IPv4 and IPv6.

**Key files and directories**
- `bunny-ip-updater.yaml` – core Kubernetes resources (CronJob, ServiceAccount, RBAC, ConfigMap)
- `examples/` – deployment blueprints, including Mastodon and NGINX integration samples
- `scripts/` – helper automation such as `setup.sh` for initial deployment and `monitor.sh` for ongoing health checks
- `docs/MASTODON_INTEGRATION.md` – step-by-step guide for integrating with the Mastodon Helm chart
- `.github/workflows/semgrep.yml` – lightweight static analysis run in CI

**Working with the project**
- Deploy the updater with `kubectl apply -f bunny-ip-updater.yaml`, or run `scripts/setup.sh` for an interactive walk-through that also performs a first-run job.
- Inspect recent runs and the resulting ConfigMap with `kubectl` directly or `scripts/monitor.sh status` / `scripts/monitor.sh compare` for richer diagnostics.
- There is no dedicated test suite; CI currently runs Semgrep checks. When contributing, validate your manifests with `kubectl apply --dry-run=client -f bunny-ip-updater.yaml` and lint shell scripts as needed.

**Tips for new contributors**
- The ConfigMap stores comma-separated IPs under the `TRUSTED_PROXY_IP` key—applications can consume it via env vars or mounted files, as shown in `README.md`.
- Review the examples to see common integration patterns, and consult `CLAUDE.md` for additional operational conventions followed by the project maintainers.
- Keep Kubernetes version compatibility (v1.19+) in mind when extending manifests, and prefer namespace-scoped resources unless a feature requires cluster-wide access.
