#!/bin/bash
# Monitoring script for Bunny IP updater

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_status() {
    echo -e "${BLUE}=== Bunny CDN IP Updater Status ===${NC}"
    echo "Date: $(date)"
    echo ""
    
    # Check CronJob
    echo -e "${BLUE}CronJob Status:${NC}"
    kubectl get cronjob bunny-ip-updater -o wide
    echo ""
    
    # Check recent jobs
    echo -e "${BLUE}Recent Jobs (last 5):${NC}"
    kubectl get jobs -l job-name=bunny-ip-updater --sort-by=.metadata.creationTimestamp | tail -6
    echo ""
    
    # Check ConfigMap
    echo -e "${BLUE}ConfigMap Status:${NC}"
    IP_COUNT=$(kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | wc -l)
    echo "Total IPs in ConfigMap: $IP_COUNT"
    
    # Show sample IPs
    echo -e "${BLUE}Sample IPs (first 5):${NC}"
    kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | head -5
    echo ""
    
    # Check last update time
    LAST_UPDATE=$(kubectl get configmap bunny-trusted-ips -o jsonpath='{.metadata.resourceVersion}')
    echo "ConfigMap Resource Version: $LAST_UPDATE"
    
    # Check if any jobs failed recently
    FAILED_JOBS=$(kubectl get jobs -l job-name=bunny-ip-updater --field-selector=status.failed=1 2>/dev/null | wc -l)
    if [ "$FAILED_JOBS" -gt 1 ]; then
        echo -e "${RED}⚠️  Warning: $((FAILED_JOBS-1)) failed jobs found${NC}"
        kubectl get jobs -l job-name=bunny-ip-updater --field-selector=status.failed=1
    else
        echo -e "${GREEN}✅ No recent failed jobs${NC}"
    fi
}

compare_api() {
    echo -e "${BLUE}=== Comparing ConfigMap with Bunny CDN API ===${NC}"
    
    # Get ConfigMap count
    CONFIGMAP_COUNT=$(kubectl get configmap bunny-trusted-ips -o jsonpath='{.data.trusted_ips}' | tr ',' '\n' | grep -v '^ | wc -l)
    
    # Get API counts
    echo "Fetching from API..."
    IPV4_COUNT=$(curl -s https://bunnycdn.com/api/system/edgeserverlist -H "Accept: application/json" | jq '. | length' 2>/dev/null || echo "0")
    IPV6_COUNT=$(curl -s https://bunnycdn.com/api/system/edgeserverlist/ipv6 -H "Accept: application/json" | jq '. | length' 2>/dev/null || echo "0")
    
    API_TOTAL=$((IPV4_COUNT + IPV6_COUNT))
    
    echo "ConfigMap IPs: $CONFIGMAP_COUNT"
    echo "API IPv4 IPs: $IPV4_COUNT"
    echo "API IPv6 IPs: $IPV6_COUNT"
    echo "API Total: $API_TOTAL"
    echo ""
    
    if [ "$CONFIGMAP_COUNT" -eq "$API_TOTAL" ] && [ "$API_TOTAL" -gt 0 ]; then
        echo -e "${GREEN}✅ IP counts match!${NC}"
    elif [ "$API_TOTAL" -eq 0 ]; then
        echo -e "${RED}❌ Failed to fetch from API${NC}"
    else
        echo -e "${YELLOW}⚠️  IP counts don't match - update may be needed${NC}"
        echo "Difference: $((API_TOTAL - CONFIGMAP_COUNT))"
    fi
}

show_logs() {
    echo -e "${BLUE}=== Latest Job Logs ===${NC}"
    LATEST_JOB=$(kubectl get jobs -l job-name=bunny-ip-updater --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
    if [ -n "$LATEST_JOB" ]; then
        kubectl logs job/$LATEST_JOB
    else
        echo "No jobs found"
    fi
}

trigger_update() {
    echo -e "${BLUE}=== Triggering Manual Update ===${NC}"
    JOB_NAME="bunny-ip-manual-$(date +%s)"
    kubectl create job $JOB_NAME --from=cronjob/bunny-ip-updater
    echo "Created job: $JOB_NAME"
    echo "Use 'kubectl logs job/$JOB_NAME -f' to follow logs"
}

# Main menu
case "${1:-status}" in
    "status")
        show_status
        ;;
    "compare")
        compare_api
        ;;
    "logs")
        show_logs
        ;;
    "trigger")
        trigger_update
        ;;
    "all")
        show_status
        echo ""
        compare_api
        ;;
    *)
        echo "Usage: $0 {status|compare|logs|trigger|all}"
        echo ""
        echo "Commands:"
        echo "  status   - Show current status and recent jobs"
        echo "  compare  - Compare ConfigMap with live API data"
        echo "  logs     - Show logs from latest job run"
        echo "  trigger  - Manually trigger IP update job"
        echo "  all      - Run status and compare"
        ;;
esac
