# BMI Auto-Scaling Application - Terraform Infrastructure

This Terraform module deploys a complete 3-tier auto-scaling architecture for the BMI Health Tracker application on AWS.

## 🏗️ Architecture

```
Internet
   ↓
[Public ALB] ← Frontend Load Balancer
   ↓
[Frontend ASG] ← 2-4 EC2 instances (Auto-scales on CPU 60%)
   ↓ (proxies /api requests)
[Internal ALB] ← Backend Load Balancer
   ↓
[Backend EC2] ← 2 fixed instances
   ↓
[Aurora Serverless v2] ← PostgreSQL (0.5-2 ACU, auto-scales)
```

## ✨ Features

- ✅ **Frontend Auto-Scaling**: CPU-based scaling (60% target)
- ✅ **Multi-AZ Deployment**: High availability across 2 availability zones
- ✅ **Serverless Database**: Aurora Serverless v2 with auto-scaling compute
- ✅ **Secure Access**: SSM Session Manager (no SSH keys needed)
- ✅ **Private Subnets**: All compute instances in private subnets
- ✅ **Modular Design**: Reusable Terraform modules
- ✅ **Golden AMIs**: Pre-baked AMIs for fast deployment (provided by instructor)
- ✅ **Cost-Optimized**: Demo-ready with ~$0.20-$0.40/hour running cost

## 📋 Prerequisites

### 1. Tools Required

- **AWS CLI** (v2.x or higher)
  ```bash
  aws --version
  ```
- **Terraform** (v1.6.0 or higher)
  ```bash
  terraform version
  ```
- **AWS Account** with appropriate permissions (Administrator or PowerUser)
- **AWS Profile** configured: `sarowar-ostad` (or update in tfvars)

### 2. Create S3 Bucket for Terraform State

**IMPORTANT**: Create this bucket BEFORE running `terraform init`

```bash
# Create S3 bucket for state storage
aws s3 mb s3://ostad-terraform-state-bmi-<yourname>-ap-south-1 --region ap-south-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket ostad-terraform-state-bmi-<yourname>-ap-south-1 \
  --versioning-configuration Status=Enabled \
  --region ap-south-1

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ostad-terraform-state-bmi-<yourname>-ap-south-1 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --region ap-south-1
```

**Naming Convention**: `ostad-terraform-state-bmi-<your-name>-ap-south-1`

Example: `ostad-terraform-state-bmi-sarowar-ap-south-1`

### 3. Golden AMI IDs (Provided by Instructor)

**DO NOT CREATE THESE** - Your instructor has already created Golden AMIs for the class:

- **Backend AMI**: `ami-032e8cf6d0d558851` (Node.js 20 + PM2 + PostgreSQL client)
- **Frontend AMI**: `ami-0dab0b890a96c6f37` (nginx + Node.js 20 + git)

These AMIs are pre-configured with all required software. You just need to use the AMI IDs in your `terraform.tfvars`.

### 4. Existing VPC Infrastructure

This deployment uses existing VPC infrastructure in `ap-south-1`:

- **VPC**: `devops-vpc` (10.0.0.0/16)
- **Public Subnets**: 
  - `devops-subnet-public1-ap-south-1a` (10.0.0.0/20)
  - `devops-subnet-public2-ap-south-1b` (10.0.16.0/20)
- **Private Subnets**: 
  - `devops-subnet-private1-ap-south-1a` (10.0.128.0/20)
  - `devops-subnet-private2-ap-south-1b` (10.0.144.0/20)
- **NAT Gateway**: `devops-regional-nat`
- **Internet Gateway**: `devops-igw`
- **S3 Gateway Endpoint**: `devops-vpce-s3`

## 🚀 Usage

### Step 1: Clone Repository

```bash
git clone https://github.com/sarowar-alam/3-tier-web-app-auto-scalling.git
cd 3-tier-web-app-auto-scalling/AutoScaling-FrontEnd-CPU/terraform
```

### Step 2: Configure Variables

Create `terraform.tfvars` from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# AWS Configuration
aws_region   = "ap-south-1"
environment  = "demo"
project_name = "bmi"

# Golden AMI IDs (Provided by instructor - DO NOT CHANGE)
backend_ami_id  = "ami-032e8cf6d0d558851"
frontend_ami_id = "ami-0dab0b890a96c6f37"

# Database Configuration
db_name     = "bmidb"
db_username = "postgres"
db_password = "YourSecurePassword123!"  # ⚠️ CHANGE THIS!

# Additional Tags
additional_tags = {
  Owner = "YourName"
  Course = "Ostad-DevOps-Batch-08"
}
```

### Step 3: Configure S3 Backend

Create `backend.hcl`:

```bash
cat > backend.hcl <<EOF
bucket  = "ostad-terraform-state-bmi-<yourname>-ap-south-1"
key     = "bmi-autoscaling/terraform.tfstate"
region  = "ap-south-1"
encrypt = true
EOF
```

Replace `<yourname>` with your actual name.

### Step 4: Initialize Terraform

```bash
terraform init -backend-config=backend.hcl
```

Expected output:
```
Initializing modules...
Initializing the backend...
Successfully configured the backend "s3"!
Initializing provider plugins...
Terraform has been successfully initialized!
```

### Step 5: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully. It will create approximately **40+ resources**:
- 3 VPC Endpoints (SSM)
- 6 Security Groups
- 1 Aurora Serverless v2 Cluster + Instance
- 1 DB Subnet Group
- 2 Application Load Balancers
- 2 Target Groups
- 2 Backend EC2 Instances
- 1 Auto Scaling Group (Frontend)
- 1 Launch Template
- 1 Target Tracking Scaling Policy
- 5 SSM Parameters
- IAM Role + Policies + Instance Profile

### Step 6: Apply Configuration

```bash
terraform apply tfplan
```

**⏱️ Deployment Time: 15-20 minutes**

Breakdown:
- Network resources: ~5 minutes
- Database (Aurora): ~10-12 minutes ⚠️ (longest step)
- Load balancers: ~2-3 minutes
- Compute instances: ~5-7 minutes

Grab a coffee while Aurora spins up! ☕

### Step 7: Access Application

After deployment completes:

```bash
# Get application URL
terraform output application_url

# Example output:
# http://bmi-fe-xxxxxxxxx.ap-south-1.elb.amazonaws.com
```

**Open the URL in your browser** to access the BMI Health Tracker!

Wait ~5 minutes after deployment for:
1. EC2 instances to complete user-data scripts
2. Backend to connect to database and run migrations
3. Frontend to build and nginx to start
4. Target groups to show healthy status

### Step 8: Verify Deployment

```bash
# Check frontend target health
terraform output -raw frontend_tg_arn | xargs -I {} aws elbv2 describe-target-health --target-group-arn {} --region ap-south-1

# Check backend target health
terraform output -raw backend_tg_arn | xargs -I {} aws elbv2 describe-target-health --target-group-arn {} --region ap-south-1

# View all outputs
terraform output
```

## 📊 Load Testing & Auto-Scaling Demo

Test the auto-scaling functionality for your class:

```bash
# Navigate to load test directory
cd ../load-test

# Run quick load test (generates CPU load)
./quick-test.sh $(terraform -chdir=../terraform output -raw application_url)

# Monitor ASG in another terminal
./monitor.sh $(terraform -chdir=../terraform output -raw frontend_asg_name) ap-south-1
```

**Expected Auto-Scaling Behavior:**

1. **Initial State**: 2 frontend instances running
2. **During Load** (2-3 minutes): CPU spikes above 60%
   - CloudWatch alarm triggers
   - ASG launches 1-2 additional instances
   - Scales to 3-4 instances
3. **After Load Stops** (~5-7 minutes cooldown):
   - CPU drops below 60%
   - ASG gradually terminates extra instances
   - Returns to 2 instances

**Perfect for classroom demonstration!** 🎓

## 🔐 Accessing Instances

All instances are in private subnets. Use SSM Session Manager:

```bash
# List backend instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bmi-demo-backend-*" \
  --query 'Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,State.Name]' \
  --output table \
  --region ap-south-1

# Connect to instance
aws ssm start-session --target i-xxxxxxxxx --region ap-south-1

# Once connected, check application status
sudo pm2 status                    # Backend: PM2 processes
sudo systemctl status nginx        # Frontend: nginx status
sudo tail -f /var/log/backend-deploy.log    # Backend deployment log
sudo tail -f /var/log/frontend-deploy.log   # Frontend deployment log
```

## 📤 Outputs

After deployment, Terraform provides these outputs:

| Output | Description |
|--------|-------------|
| `application_url` | Public URL to access the application |
| `frontend_alb_dns` | Frontend ALB DNS name |
| `backend_alb_dns` | Backend ALB DNS name (internal) |
| `database_endpoint` | Aurora cluster endpoint (sensitive) |
| `frontend_asg_name` | Frontend Auto Scaling Group name |
| `backend_instance_ids` | List of backend instance IDs |
| `monitoring_commands` | AWS CLI commands for monitoring |
| `quick_start_guide` | Quick reference guide with URLs and costs |

View all outputs:

```bash
terraform output
```

View specific output:

```bash
terraform output application_url
terraform output frontend_asg_name
```

## 💰 Cost Management

### Running Costs (~$0.20-$0.40/hour)

| Resource | Cost/Hour | Notes |
|----------|-----------|-------|
| Aurora Serverless v2 (0.5-2 ACU) | $0.06-$0.24 | Auto-scales with load |
| NAT Gateway | $0.045 | Pre-existing (shared cost) |
| ALBs (2x) | $0.04 | Frontend + Backend |
| EC2 Instances (t3.micro, 2-4) | $0.02-$0.04 | 2 backend + 2-4 frontend |
| VPC Endpoints (3x) | $0.03 | SSM access |
| **Total** | **~$0.20-$0.40/hour** | **~$5-10/day if left running** |

### Cost Optimization Features

This configuration is **demo-optimized** with:
- ✅ Aurora min capacity: 0.5 ACU (lowest possible)
- ✅ t3.micro instances (free tier eligible)
- ✅ Backup retention: 0 days (disabled)
- ✅ Performance Insights: Disabled
- ✅ CloudWatch Logs: Disabled
- ✅ Enhanced monitoring: Disabled

### ⚠️ IMPORTANT: Cleanup After Demo

**DO NOT LEAVE RESOURCES RUNNING!**

To avoid surprise charges:

```bash
terraform destroy -auto-approve
```

**Confirmation required**: Type `yes` when prompted.

**Deletion time**: ~10-15 minutes (Aurora takes longest)

**What gets deleted:**
- ✅ All EC2 instances
- ✅ Load balancers
- ✅ Aurora cluster
- ✅ VPC endpoints
- ✅ Security groups
- ✅ SSM parameters
- ✅ IAM roles/policies

**What remains (no ongoing cost):**
- Golden AMIs (unless you delete them)
- VPC infrastructure (shared, already exists)
- S3 Terraform state (minimal: ~$0.01/month)

### Cost Tracking

Monitor your costs:

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --region us-east-1
```

Set up billing alerts in AWS Console → Billing → Budgets.

## 🐛 Troubleshooting

### Frontend Not Loading

**Symptom**: ALB URL returns 503 Service Unavailable

**Diagnosis:**
```bash
# Check target health
terraform output -raw frontend_tg_arn | xargs -I {} aws elbv2 describe-target-health --target-group-arn {} --region ap-south-1
```

**Common causes:**
1. **Unhealthy targets**: Wait 5 minutes for user-data script to complete
2. **No targets**: Check ASG has launched instances
3. **Security group**: Verify frontend-alb-sg allows port 80 from 0.0.0.0/0

**Fix:**
```bash
# Connect to instance and check logs
aws ssm start-session --target i-xxxxxxxxx --region ap-south-1
sudo tail -f /var/log/frontend-deploy.log
sudo systemctl status nginx
sudo nginx -t  # Test nginx config
```

### Backend API Not Responding

**Symptom**: Frontend loads but shows "Failed to save measurement"

**Diagnosis:**
```bash
# Check backend targets
terraform output -raw backend_tg_arn | xargs -I {} aws elbv2 describe-target-health --target-group-arn {} --region ap-south-1
```

**Fix:**
```bash
# Connect to backend instance
aws ssm start-session --target i-xxxxxxxxx --region ap-south-1
sudo pm2 status
sudo pm2 logs
tail -f /var/log/backend-deploy.log

# Check database connection
sudo -u ec2-user psql -h $(aws ssm get-parameter --name /bmi-app/db-host --query Parameter.Value --output text --region ap-south-1) -U postgres -d bmidb -c "SELECT 1;"
```

### Database Connection Issues

**Symptom**: Backend logs show "ECONNREFUSED" or "Connection timeout"

**Diagnosis:**
```bash
# Verify database endpoint
terraform output database_endpoint

# Check security group rules
terraform output aurora_sg_id | xargs -I {} aws ec2 describe-security-groups --group-ids {} --region ap-south-1
```

**Common causes:**
1. **Aurora still initializing**: Wait 10-12 minutes after `terraform apply`
2. **Wrong password**: Check SSM parameter `/bmi-app/db-password`
3. **Security group**: Verify aurora-sg allows port 5432 from backend-ec2-sg

### Auto-Scaling Not Triggering

**Symptom**: Load test runs but ASG doesn't scale out

**Diagnosis:**
```bash
# Check scaling policy
terraform output -raw frontend_asg_name | xargs -I {} aws autoscaling describe-policies --auto-scaling-group-name {} --region ap-south-1

# View recent ASG activity
terraform output -raw frontend_asg_name | xargs -I {} aws autoscaling describe-scaling-activities --auto-scaling-group-name {} --max-records 10 --region ap-south-1

# Check CloudWatch metrics
terraform output -raw frontend_asg_name | xargs -I {} aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value={} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region ap-south-1
```

**Common causes:**
1. **Already at max capacity**: Check if ASG is at max_size (4 instances)
2. **Insufficient load**: CPU must stay >60% for ~3 minutes
3. **Warmup period**: New instances need 60 seconds before contributing to metrics

### SSM Session Manager Not Working

**Symptom**: `aws ssm start-session` fails with "TargetNotConnected"

**Diagnosis:**
```bash
# Check instance has correct IAM role
aws ec2 describe-instances --instance-ids i-xxxxxxxxx --query 'Reservations[*].Instances[*].IamInstanceProfile' --region ap-south-1

# Verify SSM agent is running
aws ssm describe-instance-information --region ap-south-1 | grep i-xxxxxxxxx
```

**Fix:**
1. **Wait 5 minutes** for SSM agent to register (new instances)
2. **Check VPC endpoints**: Ensure ssm/ec2messages/ssmmessages endpoints exist
3. **Security groups**: Verify ssm-endpoint-sg allows port 443 from VPC CIDR

### Terraform State Issues

**Symptom**: `terraform plan` shows unexpected changes or errors

**Diagnosis:**
```bash
# Check state file exists in S3
aws s3 ls s3://ostad-terraform-state-bmi-<yourname>-ap-south-1/bmi-autoscaling/

# View state
terraform state list
```

**Fix:**
```bash
# Refresh state from AWS
terraform refresh

# If state is corrupted, re-import resources (advanced)
terraform import module.database.aws_rds_cluster.aurora bmi-aurora-cluster
```

## 📁 Module Structure

```
terraform/
├── main.tf                    # Root module orchestration
├── providers.tf               # AWS provider configuration
├── backend.tf                 # S3 backend configuration
├── data.tf                    # Data sources for existing VPC
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variable values
├── README.md                  # This file
└── modules/
    ├── network/               # VPC endpoints & security groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── iam/                   # IAM roles and policies
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── database/              # Aurora Serverless v2
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── parameter_store/       # SSM parameters
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── load_balancing/        # ALBs and target groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute_backend/       # Backend EC2 instances
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── compute_frontend/      # Frontend Auto Scaling Group
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## 🔒 Security Best Practices

This configuration implements several security best practices:

1. **Private Subnets**: All compute instances in private subnets (no direct internet access)
2. **IMDSv2**: Instance metadata service v2 required (prevents SSRF attacks)
3. **Encrypted Storage**: EBS volumes encrypted by default
4. **Secure Passwords**: Database password stored in SecureString parameter
5. **Minimal IAM Permissions**: Least privilege IAM policies
6. **Security Groups**: Restrictive inbound/outbound rules
7. **No SSH Keys**: SSM Session Manager for secure access (no key management)
8. **HTTPS VPC Endpoints**: Encrypted communication with AWS services
9. **No Public IPs**: Backend instances have no public IP addresses
10. **Network Segmentation**: Frontend → Backend → Database isolation

## 🎓 Educational Value

This project demonstrates:

- **Auto-Scaling**: CPU-based scaling with CloudWatch metrics
- **High Availability**: Multi-AZ deployment with load balancing
- **Serverless Database**: Aurora Serverless v2 auto-scaling
- **Infrastructure as Code**: Modular Terraform design
- **AWS Networking**: VPC, subnets, route tables, NAT Gateway
- **Security**: Private subnets, security groups, IAM roles, SSM
- **Monitoring**: CloudWatch metrics and ASG activity
- **Cost Optimization**: Right-sizing for demo usage

**Perfect for DevOps training and AWS certification preparation!** 🎯

## 📚 Additional Resources

- **Manual Setup Guide**: [../QUICK-DEMO-SETUP.md](../QUICK-DEMO-SETUP.md)
- **VPC Reference**: [../EXISTING-VPC-REFERENCE.md](../EXISTING-VPC-REFERENCE.md)
- **Load Testing**: [../load-test/](../load-test/)
- **GitHub Repository**: https://github.com/sarowar-alam/3-tier-web-app-auto-scalling
- **AWS Documentation**: 
  - [Auto Scaling](https://docs.aws.amazon.com/autoscaling/)
  - [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
  - [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

## 🤝 Support

Having issues? Check:

1. **Troubleshooting section** above
2. **AWS CloudWatch Logs** for application logs
3. **Terraform state**: `terraform state list`
4. **AWS Console**: Verify resources manually
5. **Instructor**: Ask questions during class!

## ⚠️ Final Reminders

1. **Create S3 bucket BEFORE running `terraform init`**
2. **Use provided Golden AMI IDs** (do not create your own)
3. **Change database password** in `terraform.tfvars`
4. **Wait 15-20 minutes** for full deployment
5. **Test auto-scaling** with load test scripts
6. **DESTROY RESOURCES AFTER DEMO** to avoid charges!

---

**Estimated Total Class Time:**
- Setup & Deploy: 30 minutes (while Aurora creates, discuss architecture)
- Load Testing Demo: 15 minutes
- Exploration: 15 minutes
- Cleanup: 15 minutes
- **Total: ~75 minutes** ⏱️

**Remember to destroy resources after demo!**

```bash
terraform destroy -auto-approve
```

Happy learning! 🚀
