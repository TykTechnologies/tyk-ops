#!/bin/bash
set -e

echo "=== Setting up Tyk Official Helm Repository ==="

# Add Tyk Helm repository
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
helm repo update

# Verify chart availability
echo "Available Tyk charts:"
helm search repo tyk-helm/tyk-control-plane

# Generate values template for reference
helm show values tyk-helm/tyk-control-plane > kubernetes/tyk-control-plane/base-values.yaml

echo "✅ Tyk Helm repository configured successfully!"