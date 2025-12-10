#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying GrowthBook to EKS...${NC}"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}helm is not installed. Please install it first.${NC}"
    exit 1
fi

# Get cluster name from terraform output
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")

if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${YELLOW}Could not get cluster name from terraform. Please set CLUSTER_NAME environment variable.${NC}"
    if [ -z "$CLUSTER_NAME" ]; then
        read -p "Enter EKS cluster name: " CLUSTER_NAME
    fi
fi

# Update kubeconfig
echo -e "${GREEN}Updating kubeconfig for cluster: $CLUSTER_NAME${NC}"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "${AWS_REGION:-us-east-1}"

# Get S3 bucket name from terraform output
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "${AWS_REGION:-us-east-1}")

if [ -n "$S3_BUCKET" ]; then
    echo -e "${GREEN}Found S3 bucket: $S3_BUCKET${NC}"
    # Update values file with S3 bucket
    sed -i.bak "s|value: \"\"  # Will be set by Terraform output|value: \"$S3_BUCKET\"|g" growthbook-values.yaml
    sed -i.bak "s|value: \"\"  # Will be set by Terraform output|value: \"https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/\"|g" growthbook-values.yaml
    rm -f growthbook-values.yaml.bak
fi

# Add GrowthBook Helm repository
echo -e "${GREEN}Adding GrowthBook Helm repository...${NC}"
helm repo add growthbook oci://ghcr.io/growthbook/charts
helm repo update

# Install AWS Load Balancer Controller (if not already installed)
echo -e "${GREEN}Checking for AWS Load Balancer Controller...${NC}"
if ! kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
    echo -e "${YELLOW}AWS Load Balancer Controller not found. Installing...${NC}"
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Get VPC ID
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    
    if [ -z "$VPC_ID" ]; then
        echo -e "${RED}Could not get VPC ID. Please install AWS Load Balancer Controller manually.${NC}"
        exit 1
    fi
    
    # Install AWS Load Balancer Controller
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName="$CLUSTER_NAME" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller
else
    echo -e "${GREEN}AWS Load Balancer Controller already installed.${NC}"
fi

# Deploy GrowthBook
echo -e "${GREEN}Deploying GrowthBook...${NC}"
helm upgrade --install growthbook oci://ghcr.io/growthbook/charts/growthbook \
    -f growthbook-values.yaml \
    --namespace growthbook \
    --create-namespace

echo -e "${GREEN}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/growthbook-frontend -n growthbook || true
kubectl wait --for=condition=available --timeout=300s deployment/growthbook-backend -n growthbook || true

# Get ingress information
echo -e "${GREEN}Getting ingress information...${NC}"
kubectl get ingress -n growthbook

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${YELLOW}Note: It may take a few minutes for the ALB to be provisioned and DNS to be available.${NC}"
echo -e "${YELLOW}Check the ingress status with: kubectl get ingress -n growthbook${NC}"

