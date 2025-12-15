# AWS Deployment Guide for GrowthBook

This guide provides Infrastructure as Code (Terraform) configurations to deploy GrowthBook on AWS in a scalable and production-ready manner.

## Deployment Options

### Option 1: ECS Fargate (Recommended for Easy Setup)
- **Pros**: Fully managed, no server management, easy to set up, auto-scaling
- **Cons**: Less control over underlying infrastructure
- **Best for**: Teams wanting quick deployment with minimal operational overhead

### Option 2: EKS (Recommended for Maximum Scalability)
- **Pros**: Kubernetes-native, maximum scalability, uses existing Helm charts
- **Cons**: More complex setup, requires Kubernetes knowledge
- **Best for**: Teams already using Kubernetes or needing advanced orchestration

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.5.0 installed
3. **AWS CLI** configured with credentials
4. **Domain name** (optional but recommended for production)
5. **SSL Certificate** in AWS Certificate Manager (for HTTPS)

## Quick Start

### ECS Fargate Deployment

1. Navigate to the ECS directory:
   ```bash
   cd aws-deployment/ecs-fargate
   ```

2. Configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### EKS Deployment

1. Navigate to the EKS directory:
   ```bash
   cd aws-deployment/eks
   ```

2. Configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. Deploy:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. After infrastructure is created, deploy GrowthBook:
   ```bash
   ./deploy-growthbook.sh
   ```

## Architecture Overview

Both deployments include:

- **VPC** with public and private subnets across multiple AZs
- **Application Load Balancer (ALB)** with SSL termination
- **MongoDB** (DocumentDB or MongoDB Atlas)
- **S3 Bucket** for file uploads
- **Secrets Manager** for sensitive configuration
- **CloudWatch** for logging and monitoring
- **Auto Scaling** based on CPU/memory metrics
- **Security Groups** with least-privilege access

## Configuration

### Required Environment Variables

Generate secrets:
```bash
# Generate JWT secret
openssl rand -hex 32

# Generate encryption key
openssl rand -hex 32
```

### MongoDB Options

1. **AWS DocumentDB** (managed, recommended)
2. **MongoDB Atlas** (fully managed, cross-cloud)
3. **Self-hosted MongoDB** on EC2 (not recommended for production)

### File Uploads

Configure S3 bucket for uploads:
- Set `UPLOAD_METHOD=s3` in environment variables
- IAM role will be automatically configured for S3 access

## Post-Deployment

1. **Get Load Balancer URL**:
   ```bash
   terraform output alb_dns_name
   ```

2. **Configure DNS** (if using custom domain):
   - Point your domain to the ALB DNS name
   - Update `APP_ORIGIN` and `API_HOST` environment variables

3. **Access GrowthBook**:
   - Frontend: `https://your-domain.com`
   - API: `https://api.your-domain.com`

## Scaling

### ECS Fargate
- Auto-scaling is configured based on CPU and memory utilization
- Adjust `min_capacity` and `max_capacity` in `terraform.tfvars`

### EKS
- Horizontal Pod Autoscaler (HPA) is configured
- Adjust replica counts in Helm values or via HPA

## Monitoring

- **CloudWatch Logs**: Application logs are automatically sent to CloudWatch
- **CloudWatch Metrics**: CPU, memory, and request metrics
- **ALB Access Logs**: HTTP request logs

## Cost Estimation

Approximate monthly costs (us-east-1):
- **ECS Fargate**: $50-200/month (depending on traffic)
- **EKS**: $75-300/month (cluster + nodes)
- **DocumentDB**: $100-500/month (depending on instance size)
- **ALB**: $20-30/month
- **S3**: $5-20/month (depending on storage)

## Security Best Practices

1. ✅ Secrets stored in AWS Secrets Manager
2. ✅ Application runs in private subnets
3. ✅ Security groups with least-privilege access
4. ✅ SSL/TLS encryption in transit
5. ✅ Encrypted storage (DocumentDB, S3)
6. ✅ IAM roles with minimal permissions

## Troubleshooting

### Check ECS Service Status
```bash
aws ecs describe-services --cluster growthbook --services growthbook-app
```

### View Logs
```bash
aws logs tail /ecs/growthbook --follow
```

### Check EKS Pods
```bash
kubectl get pods -n growthbook
kubectl logs -n growthbook <pod-name>
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will delete all resources including databases. Make sure to backup data first!

## Support

For issues or questions:
- Check [GrowthBook Documentation](https://docs.growthbook.io/self-host)
- Join [GrowthBook Slack](https://slack.growthbook.io)
- Open an issue on GitHub

