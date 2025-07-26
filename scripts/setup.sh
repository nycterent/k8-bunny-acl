#!/bin/bash
# Setup script for Bunny IP updater

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Setting up Bunny CDN IP Updater...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if we can access the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot access Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubernetes cluster access confirmed${NC}"

# Get current context
CONTEXT=$(kubectl config current-context)
echo -e "${YELLOW}📍 Current context: $CONTEXT${NC}"

# Ask for confirmation
read -p "Deploy to this cluster? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏹️  Deployment cancelled${NC}"
    exit 0
fi

# Deploy the resources
echo -e "${BLUE}📦 Deploying Bunny IP updater...${NC}"

if kubectl apply -f ../bunny-ip-updater.yaml; then
    echo -e "${GREEN}✅ Resources deployed successfully${NC}"
else
    echo -e "${RED}❌ Failed to deploy resources${NC}"
    exit 1
fi

# Trigger initial job
echo -e "${BLUE}🔄 Triggering initial IP fetch...${NC}"
kubectl create job bunny-ip-manual-setup --from=cronjob/bunny-ip-updater

# Wait for job to complete
echo -e "${BLUE}⏳ Waiting for initial job to complete...${NC}"
kubectl wait --for=condition=complete --timeout=300s job/bunny-ip-manual-setup

# Show logs
echo -e "${BLUE}📋 Job logs:${NC}"
kubectl logs job/bunny-ip-manual-setup

# Verify ConfigMap
echo -e "${BLUE}🔍 Verifying ConfigMap...${NC}"
IP_COUNT=$(kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | wc -l)

if [ "$IP_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ ConfigMap populated with $IP_COUNT IP addresses${NC}"
    
    # Show sample IPs
    echo -e "${BLUE}📋 Sample IPs:${NC}"
    kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | head -5
else
    echo -e "${RED}❌ ConfigMap is empty${NC}"
    exit 1
fi

# Show status
echo -e "${BLUE}📊 Final status:${NC}"
kubectl get cronjob,configmap -l app.kubernetes.io/name=bunny-ip-updater

echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo -e "${BLUE}💡 Next steps:${NC}"
echo "   1. Check examples/ directory for integration patterns"
echo "   2. Use 'kubectl get configmap bunny-trusted-ips' to view IPs"
echo "   3. Monitor with 'kubectl get cronjob bunny-ip-updater'"
echo -e "${YELLOW}📅 The CronJob will run daily at 2 AM UTC${NC}"

# Cleanup the manual job
kubectl delete job bunny-ip-manual-setup
