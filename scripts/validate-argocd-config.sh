#!/bin/bash
set -e

echo "=== Validating ArgoCD Deployment Configuration ==="
echo ""

VALIDATION_ERRORS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

function check_fail() {
    echo -e "${RED}❌ $1${NC}"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
}

function check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "🔍 Checking ArgoCD Application Configuration..."

# Check ArgoCD application file exists
if [ ! -f "gitops/applications/tyk-control-plane.yaml" ]; then
    check_fail "ArgoCD application file not found: gitops/applications/tyk-control-plane.yaml"
else
    check_pass "ArgoCD application file exists"
    
    # Check chart version
    CHART_VERSION=$(grep "targetRevision:" gitops/applications/tyk-control-plane.yaml | awk '{print $2}')
    if [ "$CHART_VERSION" = "3.0.0" ]; then
        check_pass "Chart version is 3.0.0"
    else
        check_fail "Chart version is $CHART_VERSION, expected 3.0.0"
    fi
    
    # Check values file reference
    if grep -q "valueFiles:" gitops/applications/tyk-control-plane.yaml; then
        check_pass "Uses values file instead of inline configuration"
    else
        check_fail "Does not use values file reference"
    fi
fi

echo ""
echo "🔍 Checking Values File Configuration..."

# Check values file exists
if [ ! -f "gitops/tyk-control-plane/values.yaml" ]; then
    check_fail "Values file not found: gitops/tyk-control-plane/values.yaml"
else
    check_pass "Values file exists"
    
    # Check component versions
    GATEWAY_VERSION=$(grep -A10 "tyk-gateway:" gitops/tyk-control-plane/values.yaml | grep "tag:" | head -1 | awk '{print $2}')
    DASHBOARD_VERSION=$(grep -A10 "tyk-dashboard:" gitops/tyk-control-plane/values.yaml | grep "tag:" | head -1 | awk '{print $2}')
    MDCB_VERSION=$(grep -A10 "tyk-mdcb:" gitops/tyk-control-plane/values.yaml | grep "tag:" | head -1 | awk '{print $2}')
    
    if [ "$GATEWAY_VERSION" = "v5.8.1" ]; then
        check_pass "Gateway version is v5.8.1"
    else
        check_fail "Gateway version is $GATEWAY_VERSION, expected v5.8.1"
    fi
    
    if [ "$DASHBOARD_VERSION" = "v5.8.1" ]; then
        check_pass "Dashboard version is v5.8.1"
    else
        check_fail "Dashboard version is $DASHBOARD_VERSION, expected v5.8.1"
    fi
    
    if [ "$MDCB_VERSION" = "v2.8.1" ]; then
        check_pass "MDCB version is v2.8.1"
    else
        check_fail "MDCB version is $MDCB_VERSION, expected v2.8.1"
    fi
    
    # Check secret configuration
    if grep -q "useSecretName:" gitops/tyk-control-plane/values.yaml; then
        check_pass "Uses useSecretName approach for secrets"
    else
        check_fail "Does not use useSecretName approach"
    fi
    
    # Check storage type
    if grep -q "storageType: postgres" gitops/tyk-control-plane/values.yaml; then
        check_pass "Storage type set to postgres"
    else
        check_fail "Storage type not set to postgres"
    fi
    
    # Check all components enabled
    COMPONENTS=("bootstrap: true" "dashboard: true" "gateway: true" "pump: true" "mdcb: true" "devPortal: true" "operator: true")
    for component in "${COMPONENTS[@]}"; do
        if grep -q "$component" gitops/tyk-control-plane/values.yaml; then
            check_pass "Component enabled: $component"
        else
            check_fail "Component not enabled: $component"
        fi
    done
fi

echo ""
echo "🔍 Checking Secret Generation Script..."

if [ ! -f "scripts/generate-argocd-secrets.sh" ]; then
    check_fail "Secret generation script not found"
else
    check_pass "Secret generation script exists"
    
    if [ -x "scripts/generate-argocd-secrets.sh" ]; then
        check_pass "Secret generation script is executable"
    else
        check_fail "Secret generation script is not executable"
    fi
fi

echo ""
echo "🔍 Checking Environment Files..."

if [ ! -f "kubernetes/tyk-control-plane/.env" ]; then
    check_fail ".env file not found"
else
    check_pass ".env file exists"
    
    # Check required variables in .env
    source kubernetes/tyk-control-plane/.env 2>/dev/null || true
    
    REQUIRED_VARS=("DASHBOARD_LICENSE" "MDCB_LICENSE" "PORTAL_LICENSE" "OPERATOR_LICENSE" "API_SECRET" "ADMIN_SECRET" "ADMIN_FIRST_NAME" "ADMIN_LAST_NAME" "ADMIN_EMAIL" "ADMIN_PASSWORD")
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -n "${!var}" ] && [ "${!var}" != "CHANGEME_GENERATE_RANDOM_STRING" ]; then
            check_pass "$var is set in .env"
        else
            check_fail "$var is not set or needs to be updated in .env"
        fi
    done
fi

echo ""
echo "🔍 Checking Prerequisites..."

# Check if cert-manager prerequisites exist
if [ -f "gitops/prerequisites/cert-manager.yaml" ]; then
    check_pass "cert-manager prerequisite exists"
else
    check_warn "cert-manager prerequisite not found (may be installed separately)"
fi

# Check if namespace prerequisite exists
if [ -f "gitops/prerequisites/namespaces.yaml" ]; then
    check_pass "namespace prerequisite exists"
else
    check_warn "namespace prerequisite not found (will be created by ArgoCD)"
fi

echo ""
echo "📋 Validation Summary:"
echo "====================="

if [ $VALIDATION_ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All validations passed! ArgoCD deployment configuration is ready.${NC}"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Run: ./scripts/extract-infrastructure-secrets.sh"
    echo "   2. Run: ./scripts/generate-argocd-secrets.sh"
    echo "   3. Deploy: kubectl apply -f gitops/applications/tyk-control-plane.yaml"
    echo ""
    exit 0
else
    echo -e "${RED}❌ $VALIDATION_ERRORS validation error(s) found. Please fix them before deploying.${NC}"
    exit 1
fi