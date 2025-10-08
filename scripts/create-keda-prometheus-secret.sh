#!/bin/bash
#
# Create KEDA Prometheus Authentication Secret for Thanos Querier
# This script creates a secret containing the bearer token and TLS certificate
# required for KEDA to authenticate with Thanos Querier in OpenShift monitoring.
#

set -e

# Configuration
NAMESPACE=${1:-autoscaling-demo}
SECRET_NAME=${2:-keda-prometheus-secret}
TOKEN_DURATION=${3:-8760h}  # 1 year default

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "KEDA Prometheus Secret Creator"
echo "============================================"
echo "Target Namespace: $NAMESPACE"
echo "Secret Name: $SECRET_NAME"
echo "Token Duration: $TOKEN_DURATION"
echo ""

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Namespace '$NAMESPACE' does not exist${NC}"
    echo "Create it with: oc create namespace $NAMESPACE"
    exit 1
fi

# Check if secret already exists
if oc get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Warning: Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        oc delete secret "$SECRET_NAME" -n "$NAMESPACE"
        echo -e "${GREEN}Deleted existing secret${NC}"
    else
        echo "Exiting without changes"
        exit 0
    fi
fi

echo ""
echo "Step 1: Extracting TLS certificate from Thanos Querier..."
CA_CERT=$(oc get secret thanos-querier-tls -n openshift-monitoring -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d)

if [ -z "$CA_CERT" ]; then
    echo -e "${RED}Error: Failed to extract TLS certificate from thanos-querier-tls secret${NC}"
    echo "Make sure you have access to the openshift-monitoring namespace"
    exit 1
fi

echo -e "${GREEN}✓ TLS certificate extracted successfully${NC}"

echo ""
echo "Step 2: Creating service account token for Thanos Querier..."
TOKEN=$(oc create token thanos-querier -n openshift-monitoring --duration="$TOKEN_DURATION" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: Failed to create token for thanos-querier service account${NC}"
    echo "Make sure you have permission to create tokens in the openshift-monitoring namespace"
    exit 1
fi

echo -e "${GREEN}✓ Token created successfully (valid for $TOKEN_DURATION)${NC}"

echo ""
echo "Step 3: Creating secret in namespace '$NAMESPACE'..."
oc create secret generic "$SECRET_NAME" \
    --from-literal=token="$TOKEN" \
    --from-literal=ca.crt="$CA_CERT" \
    -n "$NAMESPACE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Secret '$SECRET_NAME' created successfully${NC}"
else
    echo -e "${RED}Error: Failed to create secret${NC}"
    exit 1
fi

echo ""
echo "============================================"
echo "Success!"
echo "============================================"
echo ""
echo "Secret Details:"
echo "  Name: $SECRET_NAME"
echo "  Namespace: $NAMESPACE"
echo "  Keys: token, ca.crt"
echo ""
echo "Next Steps:"
echo "1. Deploy KEDA operator (if not already installed):"
echo "   helm install keda helm/keda-operator/ -n openshift-keda"
echo ""
echo "2. Enable KEDA autoscaling in your Helm chart:"
echo "   helm upgrade llama3-2-3b helm/llama3.2-3b/ \\"
echo "     --set keda.enabled=true \\"
echo "     --set keda.prometheus.secretName=$SECRET_NAME \\"
echo "     -n $NAMESPACE"
echo ""
echo "3. Monitor the ScaledObject:"
echo "   oc get scaledobject -n $NAMESPACE"
echo "   oc describe scaledobject llama3-2-3b -n $NAMESPACE"
echo ""
echo "4. Check HPA created by KEDA:"
echo "   oc get hpa -n $NAMESPACE"
echo ""
echo "Note: Token expires after $TOKEN_DURATION"
echo "      Recreate this secret before expiration"
echo ""
