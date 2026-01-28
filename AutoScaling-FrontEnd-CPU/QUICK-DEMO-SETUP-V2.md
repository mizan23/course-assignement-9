# AWS Auto-Scaling Demo - Frontend CPU-Based Scaling (Verified Setup)

**Comprehensive 1-Hour Setup Guide for BMI Health Tracker with Verification Checkpoints**

This guide sets up a 3-tier architecture with **Frontend Auto-Scaling based on CPU utilization** (60% target) with detailed verification steps after each phase.

---

## Architecture Overview

```
Internet
   ↓
[Public ALB] ← Frontend Load Balancer (Internet-facing)
   ↓
[Frontend ASG] ← 2-4 EC2 instances (Auto-scales on CPU 60%)
   ↓ (proxies /api requests)
[Internal ALB] ← Backend Load Balancer (Private)
   ↓
[Backend EC2] ← 2 fixed instances (No auto-scaling)
   ↓
[Aurora Serverless v2] ← PostgreSQL (0.5-2 ACU, auto-scales)
```

**Key Features:**
- ✅ Frontend auto-scales based on CPU utilization (60% target)
- ✅ Backend fixed at 2 instances (no auto-scaling)
- ✅ Aurora Serverless v2 auto-scales compute (0.5→2 ACU)
- ✅ SSM Session Manager for secure access (no SSH keys)
- ✅ All instances in private subnets (frontend + backend)
- ✅ Multi-AZ setup for high availability
- ✅ **Verification checkpoints after every step**
- ✅ **Amazon Linux 2023 compatible**

**Estimated Costs:**
- ~$2-3 for 1-hour demo
- ~$10-15 if left running for 24 hours

**Region:** **ap-south-1 (Mumbai)**

---

## Prerequisites

### Required Tools
- ✅ AWS Account with admin access
- ✅ AWS CLI v2 installed locally
- ✅ Basic understanding of AWS Console
- ✅ GitHub repo access: `https://github.com/sarowar-alam/3-tier-web-app-auto-scalling.git`

### Optional (for load testing)
- Apache Bench (`ab`) - for load testing
- `jq` - for JSON parsing in monitoring scripts

---

## Phase 0: Pre-Flight Checks (5 minutes)

Before starting, verify your environment is properly configured.

### Step 0.1: Verify AWS CLI Installation

Run these commands in your terminal (PowerShell on Windows):

```powershell
# Check AWS CLI version (should be 2.x or higher)
aws --version
```

**Expected output:**
```
aws-cli/2.x.x Python/3.x.x Windows/10 exe/AMD64
```

### Step 0.2: Verify AWS Credentials

```powershell
# Check current AWS identity
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Step 0.3: Set and Verify AWS Region

```powershell
# Set default region to ap-south-1 (Mumbai)
aws configure set region ap-south-1

# Verify region configuration
aws configure get region
```

**Expected output:**
```
ap-south-1
```

### Step 0.4: Verify VPC Existence

```powershell
# Check if devops-vpc exists
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=devops-vpc" --region ap-south-1 --query 'Vpcs[0].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table
```

**Expected output:**
```
-----------------------------------
|         DescribeVpcs            |
+----------------+----------------+
|  vpc-xxxxxxxx  |  10.0.0.0/16  |  devops-vpc  |
+----------------+----------------+
```

### Step 0.5: Verify Subnets

```powershell
# List all subnets in devops-vpc
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<YOUR-VPC-ID>" --region ap-south-1 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' --output table
```

**Expected output should show:**
- 2 public subnets (10.0.0.0/20, 10.0.16.0/20)
- 2 private subnets (10.0.128.0/20, 10.0.144.0/20)

### Step 0.6: Test Internet Connectivity

```powershell
# Test connectivity to AWS services
curl -I https://ap-south-1.console.aws.amazon.com
```

**Expected:** HTTP 200 or 301 response

---

## ✅ Pre-Flight Verification Checklist

Before proceeding, ensure all items are checked:

- [ ] AWS CLI version 2.x installed and working
- [ ] AWS credentials configured and verified
- [ ] Region set to **ap-south-1**
- [ ] VPC `devops-vpc` exists with CIDR 10.0.0.0/16
- [ ] 2 public subnets and 2 private subnets exist
- [ ] NAT Gateway `devops-regional-nat` exists
- [ ] Internet Gateway `devops-igw` attached to VPC

**If all checks pass, proceed to Phase 1.** ✅

---

## Phase 1: Network Setup - VPC Endpoints (5 minutes)

### Overview
Since `devops-vpc` already exists, we only need to create SSM VPC endpoints for secure Session Manager access to private instances.

### Step 1.1: Create Security Group for SSM Endpoints

**AWS Console Steps:**
1. Navigate to **VPC** → **Security Groups**
2. Click **Create security group**
3. Configure:
   - **Security group name**: `ssm-endpoint-sg`
   - **Description**: `Security group for SSM VPC endpoints`
   - **VPC**: Select `devops-vpc`
4. **Inbound rules:**
   - Click **Add rule**
   - **Type**: `HTTPS` (automatically sets port 443)
   - **Source**: `Custom` → `10.0.0.0/16`
   - **Description**: `Allow HTTPS from VPC CIDR`
5. **Outbound rules:** Leave default (All traffic to 0.0.0.0/0)
6. Click **Create security group**
7. **Note the Security Group ID** (e.g., `sg-xxxxxxxxxxxxxxxxx`)

**AWS CLI (Alternative):**

```powershell
# Create SSM endpoint security group
$vpcId = (aws ec2 describe-vpcs --filters "Name=tag:Name,Values=devops-vpc" --region ap-south-1 --query 'Vpcs[0].VpcId' --output text)

aws ec2 create-security-group `
    --group-name ssm-endpoint-sg `
    --description "Security group for SSM VPC endpoints" `
    --vpc-id $vpcId `
    --region ap-south-1

# Get the security group ID
$ssmSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=ssm-endpoint-sg" "Name=vpc-id,Values=$vpcId" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Add inbound rule for HTTPS from VPC
aws ec2 authorize-security-group-ingress `
    --group-id $ssmSgId `
    --protocol tcp `
    --port 443 `
    --cidr 10.0.0.0/16 `
    --region ap-south-1
```

### ✅ Verification Step 1.1

```powershell
# Verify security group exists and has correct inbound rule
aws ec2 describe-security-groups --group-names ssm-endpoint-sg --region ap-south-1 --query 'SecurityGroups[0].[GroupId,GroupName,IpPermissions[0].[FromPort,ToPort,IpRanges[0].CidrIp]]' --output table
```

**Expected output:**
```
----------------------------------------------------
|              DescribeSecurityGroups              |
+------------------+-------------------------------+
|  sg-xxxxxxxxxxxx |  ssm-endpoint-sg             |
+------------------+-------------------------------+
||                   443 | 443 | 10.0.0.0/16     ||
+------------------+-------------------------------+
```

**Success criteria:**
- ✅ Security group `ssm-endpoint-sg` created
- ✅ Inbound rule allows HTTPS (443) from 10.0.0.0/16
- ✅ VPC is `devops-vpc`

---

### Step 1.2: Get Private Subnet IDs

We need the subnet IDs for endpoint creation.

```powershell
# Get private subnet IDs
$privateSubnet1 = (aws ec2 describe-subnets --filters "Name=tag:Name,Values=devops-subnet-private1-ap-south-1a" --region ap-south-1 --query 'Subnets[0].SubnetId' --output text)
$privateSubnet2 = (aws ec2 describe-subnets --filters "Name=tag:Name,Values=devops-subnet-private2-ap-south-1b" --region ap-south-1 --query 'Subnets[0].SubnetId' --output text)

# Display for verification
Write-Host "Private Subnet 1: $privateSubnet1"
Write-Host "Private Subnet 2: $privateSubnet2"
```

### ✅ Verification Step 1.2

**Expected output format:**
```
Private Subnet 1: subnet-xxxxxxxxxxxxxxxxx
Private Subnet 2: subnet-yyyyyyyyyyyyyyyyy
```

**Success criteria:**
- ✅ Both subnet IDs retrieved successfully
- ✅ IDs start with `subnet-`

---

### Step 1.3: Create SSM VPC Endpoint

**AWS Console Steps:**
1. Navigate to **VPC** → **Endpoints**
2. Click **Create endpoint**
3. Configure:
   - **Name tag**: `bmi-ssm-endpoint`
   - **Service category**: `AWS services`
   - **Service Name**: Search and select `com.amazonaws.ap-south-1.ssm`
   - **VPC**: Select `devops-vpc`
   - **Subnets**: 
     - Select **ap-south-1a** → choose `devops-subnet-private1-ap-south-1a`
     - Select **ap-south-1b** → choose `devops-subnet-private2-ap-south-1b`
   - **Security groups**: Select `ssm-endpoint-sg`
   - **Policy**: `Full access`
4. Click **Create endpoint**
5. Wait ~2 minutes for status to change to **Available**

**AWS CLI (Alternative):**

```powershell
# Get security group ID
$ssmSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=ssm-endpoint-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Create SSM endpoint
aws ec2 create-vpc-endpoint `
    --vpc-id $vpcId `
    --vpc-endpoint-type Interface `
    --service-name com.amazonaws.ap-south-1.ssm `
    --subnet-ids $privateSubnet1 $privateSubnet2 `
    --security-group-ids $ssmSgId `
    --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=bmi-ssm-endpoint}]" `
    --region ap-south-1
```

### ✅ Verification Step 1.3

```powershell
# Check endpoint status
aws ec2 describe-vpc-endpoints --filters "Name=tag:Name,Values=bmi-ssm-endpoint" --region ap-south-1 --query 'VpcEndpoints[0].[VpcEndpointId,State,ServiceName]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|                   DescribeVpcEndpoints                   |
+--------------------------+---------------+---------------+
|  vpce-xxxxxxxxxxxxxxxxx  |  available    | com.amazonaws.ap-south-1.ssm |
+--------------------------+---------------+---------------+
```

**Success criteria:**
- ✅ Endpoint state is **available**
- ✅ Service name is `com.amazonaws.ap-south-1.ssm`
- ✅ Connected to both private subnets

---

### Step 1.4: Create EC2 Messages VPC Endpoint

**AWS Console Steps:**
1. Click **Create endpoint** again
2. Configure:
   - **Name tag**: `bmi-ec2messages-endpoint`
   - **Service Name**: `com.amazonaws.ap-south-1.ec2messages`
   - **VPC**: `devops-vpc`
   - **Subnets**: Select **both private subnets** (same as above)
   - **Security groups**: Select `ssm-endpoint-sg`
3. Click **Create endpoint**

**AWS CLI (Alternative):**

```powershell
aws ec2 create-vpc-endpoint `
    --vpc-id $vpcId `
    --vpc-endpoint-type Interface `
    --service-name com.amazonaws.ap-south-1.ec2messages `
    --subnet-ids $privateSubnet1 $privateSubnet2 `
    --security-group-ids $ssmSgId `
    --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=bmi-ec2messages-endpoint}]" `
    --region ap-south-1
```

### ✅ Verification Step 1.4

```powershell
aws ec2 describe-vpc-endpoints --filters "Name=tag:Name,Values=bmi-ec2messages-endpoint" --region ap-south-1 --query 'VpcEndpoints[0].[VpcEndpointId,State]' --output table
```

**Expected:** State is **available**

---

### Step 1.5: Create SSM Messages VPC Endpoint

**AWS Console Steps:**
1. Click **Create endpoint**
2. Configure:
   - **Name tag**: `bmi-ssmmessages-endpoint`
   - **Service Name**: `com.amazonaws.ap-south-1.ssmmessages`
   - **VPC**: `devops-vpc`
   - **Subnets**: Select **both private subnets**
   - **Security groups**: Select `ssm-endpoint-sg`
3. Click **Create endpoint**

**AWS CLI (Alternative):**

```powershell
aws ec2 create-vpc-endpoint `
    --vpc-id $vpcId `
    --vpc-endpoint-type Interface `
    --service-name com.amazonaws.ap-south-1.ssmmessages `
    --subnet-ids $privateSubnet1 $privateSubnet2 `
    --security-group-ids $ssmSgId `
    --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=bmi-ssmmessages-endpoint}]" `
    --region ap-south-1
```

### ✅ Verification Step 1.5

```powershell
aws ec2 describe-vpc-endpoints --filters "Name=tag:Name,Values=bmi-ssmmessages-endpoint" --region ap-south-1 --query 'VpcEndpoints[0].[VpcEndpointId,State]' --output table
```

**Expected:** State is **available**

---

### ✅ Phase 1 Complete Verification

Verify all 3 endpoints are created and available:

```powershell
# List all SSM-related endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpcId" "Name=tag:Name,Values=bmi-*" --region ap-south-1 --query 'VpcEndpoints[*].[Tags[?Key==`Name`].Value|[0],State,ServiceName]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|                   DescribeVpcEndpoints                   |
+---------------------------+------------+------------------+
|  bmi-ssm-endpoint         | available  | ...ssm           |
|  bmi-ec2messages-endpoint | available  | ...ec2messages   |
|  bmi-ssmmessages-endpoint | available  | ...ssmmessages   |
+---------------------------+------------+------------------+
```

**Success criteria:**
- ✅ All 3 endpoints show **available** state
- ✅ All endpoints connected to both private subnets
- ✅ Security group `ssm-endpoint-sg` attached to all

**If all checks pass, proceed to Phase 2.** ✅

---

## Phase 2: Database Setup - Aurora Serverless v2 (15 minutes)

### Overview
Create Aurora PostgreSQL Serverless v2 cluster for the application database. This will auto-scale compute from 0.5 to 2 ACU based on workload.

### Step 2.1: Create DB Subnet Group

**AWS Console Steps:**
1. Navigate to **RDS** → **Subnet groups**
2. Click **Create DB subnet group**
3. Configure:
   - **Name**: `bmi-db-subnet-group`
   - **Description**: `Subnet group for BMI Aurora cluster in private subnets`
   - **VPC**: Select `devops-vpc`
4. **Add subnets:**
   - **Availability Zones**: Select `ap-south-1a` and `ap-south-1b`
   - **Subnets**: Select both private subnets:
     - `devops-subnet-private1-ap-south-1a` (10.0.128.0/20)
     - `devops-subnet-private2-ap-south-1b` (10.0.144.0/20)
5. Click **Create**

**AWS CLI (Alternative):**

```powershell
# Create DB subnet group
aws rds create-db-subnet-group `
    --db-subnet-group-name bmi-db-subnet-group `
    --db-subnet-group-description "Subnet group for BMI Aurora cluster" `
    --subnet-ids $privateSubnet1 $privateSubnet2 `
    --region ap-south-1 `
    --tags Key=Name,Value=bmi-db-subnet-group
```

### ✅ Verification Step 2.1

```powershell
# Verify DB subnet group
aws rds describe-db-subnet-groups --db-subnet-group-name bmi-db-subnet-group --region ap-south-1 --query 'DBSubnetGroups[0].[DBSubnetGroupName,VpcId,Subnets[*].SubnetIdentifier]' --output table
```

**Expected output:**
```
-----------------------------------------------------------------
|                   DescribeDBSubnetGroups                      |
+------------------------+----------------+---------------------+
|  bmi-db-subnet-group  |  vpc-xxxxxxx  | subnet-xxx, subnet-yyy |
+------------------------+----------------+---------------------+
```

**Success criteria:**
- ✅ DB subnet group created
- ✅ Contains 2 subnets in different AZs
- ✅ VPC is `devops-vpc`

---

### Step 2.2: Create Aurora Security Group

**AWS Console Steps:**
1. Navigate to **EC2** → **Security Groups**
2. Click **Create security group**
3. Configure:
   - **Security group name**: `aurora-sg`
   - **Description**: `Security group for Aurora PostgreSQL cluster`
   - **VPC**: Select `devops-vpc`
4. **Inbound rules:**
   - Click **Add rule**
   - **Type**: `PostgreSQL` (automatically sets port 5432)
   - **Source**: `Custom` → `10.0.0.0/16`
   - **Description**: `Allow PostgreSQL from VPC`
5. Click **Create security group**

**AWS CLI (Alternative):**

```powershell
# Create Aurora security group
aws ec2 create-security-group `
    --group-name aurora-sg `
    --description "Security group for Aurora PostgreSQL cluster" `
    --vpc-id $vpcId `
    --region ap-south-1

# Get the security group ID
$auroraSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=aurora-sg" "Name=vpc-id,Values=$vpcId" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Add inbound rule for PostgreSQL from VPC
aws ec2 authorize-security-group-ingress `
    --group-id $auroraSgId `
    --protocol tcp `
    --port 5432 `
    --cidr 10.0.0.0/16 `
    --region ap-south-1
```

### ✅ Verification Step 2.2

```powershell
# Verify Aurora security group
aws ec2 describe-security-groups --group-names aurora-sg --region ap-south-1 --query 'SecurityGroups[0].[GroupId,GroupName,IpPermissions[0].[FromPort,IpRanges[0].CidrIp]]' --output table
```

**Expected output:**
```
----------------------------------------------------
|              DescribeSecurityGroups              |
+------------------+-------------------------------+
|  sg-xxxxxxxxxxxx |  aurora-sg                   |
+------------------+-------------------------------+
||                   5432 | 10.0.0.0/16           ||
+------------------+-------------------------------+
```

**Success criteria:**
- ✅ Security group created
- ✅ Port 5432 open to 10.0.0.0/16

---

### Step 2.3: Create Aurora Serverless v2 Cluster

**Important:** This takes 10-12 minutes. Start this step and monitor progress.

**AWS Console Steps:**
1. Navigate to **RDS** → **Databases**
2. Click **Create database**
3. **Choose a database creation method**: `Standard create`
4. **Engine options:**
   - **Engine type**: `Aurora (PostgreSQL Compatible)`
   - **Engine version**: `Aurora PostgreSQL (Compatible with PostgreSQL 15.5)` or latest 15.x
   - **Edition**: `Aurora PostgreSQL-Compatible edition`
5. **Templates:** Select `Dev/Test` (not Production - saves cost)
6. **Settings:**
   - **DB cluster identifier**: `bmi-aurora-cluster`
   - **Master username**: `postgres`
   - **Credentials management**: `Self managed`
   - **Master password**: `BMIApp2024Secure!` (remember this!)
   - **Confirm password**: `BMIApp2024Secure!`
7. **Instance configuration:**
   - **DB instance class**: Select `Serverless`
   - **Minimum Aurora capacity unit (ACUs)**: `0.5`
   - **Maximum Aurora capacity unit (ACUs)**: `2`
8. **Connectivity:**
   - **Compute resource**: `Don't connect to an EC2 compute resource`
   - **Network type**: `IPv4`
   - **Virtual private cloud (VPC)**: Select `devops-vpc`
   - **DB subnet group**: Select `bmi-db-subnet-group`
   - **Public access**: `No` ⚠️ (must be No!)
   - **VPC security group**: Choose existing → Select `aurora-sg`
   - **Availability Zone**: `No preference`
9. **Database authentication:**
   - Leave **Password authentication** selected
10. **Additional configuration:**
    - **Initial database name**: `bmidb` ⚠️ (don't skip this!)
    - **DB cluster parameter group**: Default
    - **Backup retention period**: `1 day` (for demo)
    - **Backup window**: `No preference`
    - **Enable auto minor version upgrade**: `Yes`
    - **Maintenance window**: `No preference`
11. **Monitoring:**
    - **Enhanced monitoring**: `Disable` (for demo)
    - **Performance Insights**: `Disable` (for demo)
12. Click **Create database**

**Note:** For production, enable backups, Enhanced Monitoring, and Performance Insights.

### ⏱️ Wait Time: 10-12 minutes

While Aurora is being created, you can:
- Review Phase 3 (IAM Role Setup)
- Prepare Parameter Store values
- Have coffee ☕

### ✅ Verification Step 2.3

**Check creation status:**

```powershell
# Monitor Aurora cluster status
aws rds describe-db-clusters --db-cluster-identifier bmi-aurora-cluster --region ap-south-1 --query 'DBClusters[0].[DBClusterIdentifier,Status,Endpoint,ReaderEndpoint,EngineVersion]' --output table
```

**During creation, status will be:** `creating`

**When ready, expected output:**
```
------------------------------------------------------------
|                   DescribeDBClusters                     |
+---------------------+------------+------------------------+
| bmi-aurora-cluster  | available  | bmi-aurora-cluster.cluster-xxxxx.ap-south-1.rds.amazonaws.com |
+---------------------+------------+------------------------+
```

**Get the Writer Endpoint (you'll need this!):**

```powershell
# Get and save the Aurora writer endpoint
$auroraEndpoint = (aws rds describe-db-clusters --db-cluster-identifier bmi-aurora-cluster --region ap-south-1 --query 'DBClusters[0].Endpoint' --output text)
Write-Host "Aurora Writer Endpoint: $auroraEndpoint"
```

**Example output:**
```
Aurora Writer Endpoint: bmi-aurora-cluster.cluster-c1234567890a.ap-south-1.rds.amazonaws.com
```

**Copy this endpoint - you'll need it for Parameter Store!**

### ✅ Test Database Connection (Optional but Recommended)

Once Aurora is available, you can test connectivity from your local machine using `psql` (if you have it installed):

```powershell
# Test connection (only works if your IP has network access to VPC)
# This will likely fail unless you're connected via VPN - that's expected
psql -h $auroraEndpoint -U postgres -d bmidb
# Password: BMIApp2024Secure!
```

**If you can't connect:** That's expected! Aurora is in private subnets. We'll test from EC2 instances later.

---

### ✅ Phase 2 Complete Verification

Run all verification commands:

```powershell
# 1. Verify DB subnet group
aws rds describe-db-subnet-groups --db-subnet-group-name bmi-db-subnet-group --region ap-south-1 --query 'DBSubnetGroups[0].DBSubnetGroupName' --output text

# 2. Verify Aurora security group
aws ec2 describe-security-groups --group-names aurora-sg --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text

# 3. Verify Aurora cluster is available
aws rds describe-db-clusters --db-cluster-identifier bmi-aurora-cluster --region ap-south-1 --query 'DBClusters[0].Status' --output text

# 4. Get Aurora endpoint (save this!)
$auroraEndpoint = (aws rds describe-db-clusters --db-cluster-identifier bmi-aurora-cluster --region ap-south-1 --query 'DBClusters[0].Endpoint' --output text)
Write-Host "✅ Aurora Endpoint: $auroraEndpoint"
```

**Success criteria:**
- ✅ DB subnet group exists with 2 private subnets
- ✅ Aurora security group allows port 5432 from VPC
- ✅ Aurora cluster status is **available**
- ✅ Writer endpoint is retrieved and saved
- ✅ Initial database `bmidb` was created
- ✅ Serverless v2 configuration: 0.5-2 ACU

**Save these values for later:**
- **Aurora Endpoint:** `<your-endpoint>.ap-south-1.rds.amazonaws.com`
- **Database Name:** `bmidb`
- **Username:** `postgres`
- **Password:** `BMIApp2024Secure!`

**If all checks pass, proceed to Phase 3.** ✅

---

## Phase 3: IAM Role Setup (5 minutes)

### Overview
Create an IAM role for EC2 instances with permissions for SSM access and Parameter Store.

### Step 3.1: Create IAM Role for EC2

**AWS Console Steps:**
1. Navigate to **IAM** → **Roles**
2. Click **Create role**
3. **Select trusted entity:**
   - **Trusted entity type**: `AWS service`
   - **Use case**: Select `EC2`
   - Click **Next**
4. **Add permissions:**
   - Search for `AmazonSSMManagedInstanceCore`
   - Check the box next to it
   - Search for `CloudWatchAgentServerPolicy`
   - Check the box next to it
   - Click **Next**
5. **Name, review, and create:**
   - **Role name**: `EC2RoleForBMIApp`
   - **Description**: `IAM role for BMI App EC2 instances with SSM and Parameter Store access`
   - Click **Create role**

**AWS CLI (Alternative):**

```powershell
# Create trust policy for EC2
$trustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

# Save trust policy to file
$trustPolicy | Out-File -FilePath trust-policy.json -Encoding utf8

# Create IAM role
aws iam create-role `
    --role-name EC2RoleForBMIApp `
    --assume-role-policy-document file://trust-policy.json `
    --description "IAM role for BMI App EC2 instances" `
    --region ap-south-1

# Attach managed policies
aws iam attach-role-policy `
    --role-name EC2RoleForBMIApp `
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam attach-role-policy `
    --role-name EC2RoleForBMIApp `
    --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### ✅ Verification Step 3.1

```powershell
# Verify IAM role exists
aws iam get-role --role-name EC2RoleForBMIApp --query 'Role.[RoleName,Arn]' --output table

# Verify attached policies
aws iam list-attached-role-policies --role-name EC2RoleForBMIApp --query 'AttachedPolicies[*].[PolicyName]' --output table
```

**Expected output:**
```
-----------------------------------------------------------
|                       GetRole                           |
+-----------------------+---------------------------------+
|  EC2RoleForBMIApp     | arn:aws:iam::123456789012:role/EC2RoleForBMIApp |
+-----------------------+---------------------------------+

-----------------------------------------------------------
|              ListAttachedRolePolicies                   |
+-------------------------------------------------------+
|  AmazonSSMManagedInstanceCore                         |
|  CloudWatchAgentServerPolicy                          |
+-------------------------------------------------------+
```

**Success criteria:**
- ✅ Role `EC2RoleForBMIApp` created
- ✅ `AmazonSSMManagedInstanceCore` policy attached
- ✅ `CloudWatchAgentServerPolicy` policy attached

---

### Step 3.2: Add Inline Policy for Parameter Store Access

**AWS Console Steps:**
1. Navigate to **IAM** → **Roles**
2. Find and click on `EC2RoleForBMIApp`
3. Go to **Permissions** tab
4. Click **Add permissions** → **Create inline policy**
5. Click **JSON** tab
6. Replace the policy with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ParameterStoreRead",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:ap-south-1:*:parameter/bmi-app/*"
    },
    {
      "Sid": "KMSDecrypt",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "ssm.ap-south-1.amazonaws.com"
        }
      }
    }
  ]
}
```

7. Click **Review policy**
8. **Name**: `BMIAppParameterStoreAccess`
9. Click **Create policy**

**AWS CLI (Alternative):**

```powershell
# Create inline policy
$inlinePolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ParameterStoreRead",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:ap-south-1:*:parameter/bmi-app/*"
    },
    {
      "Sid": "KMSDecrypt",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "ssm.ap-south-1.amazonaws.com"
        }
      }
    }
  ]
}
"@

# Save to file
$inlinePolicy | Out-File -FilePath parameter-store-policy.json -Encoding utf8

# Create inline policy
aws iam put-role-policy `
    --role-name EC2RoleForBMIApp `
    --policy-name BMIAppParameterStoreAccess `
    --policy-document file://parameter-store-policy.json
```

### ✅ Verification Step 3.2

```powershell
# Verify inline policy
aws iam get-role-policy --role-name EC2RoleForBMIApp --policy-name BMIAppParameterStoreAccess --query 'PolicyName' --output text

# List all policies (managed + inline)
aws iam list-role-policies --role-name EC2RoleForBMIApp --query 'PolicyNames' --output table
```

**Expected output:**
```
BMIAppParameterStoreAccess

------------------------------------
|        ListRolePolicies          |
+----------------------------------+
|  BMIAppParameterStoreAccess      |
+----------------------------------+
```

**Success criteria:**
- ✅ Inline policy `BMIAppParameterStoreAccess` added
- ✅ Policy allows read access to `/bmi-app/*` parameters
- ✅ Policy includes KMS decrypt for SecureString parameters

---

### Step 3.3: Create Instance Profile

Instance profiles are required to attach IAM roles to EC2 instances.

**AWS Console Steps:**
The instance profile is automatically created when you create a role via Console. Verify it exists:

**AWS CLI:**

```powershell
# Create instance profile
aws iam create-instance-profile `
    --instance-profile-name EC2RoleForBMIApp `
    --region ap-south-1

# Add role to instance profile
aws iam add-role-to-instance-profile `
    --instance-profile-name EC2RoleForBMIApp `
    --role-name EC2RoleForBMIApp
```

### ✅ Verification Step 3.3

```powershell
# Verify instance profile
aws iam get-instance-profile --instance-profile-name EC2RoleForBMIApp --query 'InstanceProfile.[InstanceProfileName,Roles[0].RoleName]' --output table
```

**Expected output:**
```
---------------------------------------
|        GetInstanceProfile           |
+--------------------+----------------+
|  EC2RoleForBMIApp  | EC2RoleForBMIApp |
+--------------------+----------------+
```

**Success criteria:**
- ✅ Instance profile exists
- ✅ Role is attached to instance profile

---

### ✅ Phase 3 Complete Verification

```powershell
# Complete role verification
Write-Host "=== Phase 3 Verification ===" -ForegroundColor Green

# 1. Check role exists
$roleCheck = aws iam get-role --role-name EC2RoleForBMIApp --query 'Role.RoleName' --output text
Write-Host "✅ IAM Role: $roleCheck"

# 2. Check managed policies
$managedPolicies = aws iam list-attached-role-policies --role-name EC2RoleForBMIApp --query 'AttachedPolicies[*].PolicyName' --output text
Write-Host "✅ Managed Policies: $managedPolicies"

# 3. Check inline policy
$inlinePolicy = aws iam list-role-policies --role-name EC2RoleForBMIApp --query 'PolicyNames[0]' --output text
Write-Host "✅ Inline Policy: $inlinePolicy"

# 4. Check instance profile
$instanceProfile = aws iam get-instance-profile --instance-profile-name EC2RoleForBMIApp --query 'InstanceProfile.InstanceProfileName' --output text
Write-Host "✅ Instance Profile: $instanceProfile"

Write-Host "`n✅ Phase 3 Complete - IAM Role ready for EC2 instances" -ForegroundColor Green
```

**Success criteria:**
- ✅ IAM role `EC2RoleForBMIApp` exists
- ✅ Has 2 managed policies (SSM + CloudWatch)
- ✅ Has 1 inline policy (Parameter Store access)
- ✅ Instance profile created and linked

**If all checks pass, proceed to Phase 4.** ✅

---

## Phase 4: Parameter Store Configuration (3 minutes)

### Overview
Store sensitive configuration values (database credentials, ALB URLs) in AWS Systems Manager Parameter Store. EC2 instances will fetch these securely at runtime.

### Step 4.1: Create Database Host Parameter

**AWS Console Steps:**
1. Navigate to **Systems Manager** → **Parameter Store**
2. Click **Create parameter**
3. Configure:
   - **Name**: `/bmi-app/db-host`
   - **Description**: `Aurora cluster writer endpoint`
   - **Tier**: `Standard`
   - **Type**: `String`
   - **Data type**: `text`
   - **Value**: Paste your Aurora endpoint from Phase 2
     - Example: `bmi-aurora-cluster.cluster-c1234567890a.ap-south-1.rds.amazonaws.com`
4. Click **Create parameter**

**AWS CLI (Alternative):**

```powershell
# Use the Aurora endpoint saved earlier
aws ssm put-parameter `
    --name "/bmi-app/db-host" `
    --description "Aurora cluster writer endpoint" `
    --value $auroraEndpoint `
    --type String `
    --region ap-south-1
```

### ✅ Verification Step 4.1

```powershell
# Verify parameter exists and retrieve value
aws ssm get-parameter --name "/bmi-app/db-host" --region ap-south-1 --query 'Parameter.[Name,Value]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|                    GetParameter                          |
+------------------------+---------------------------------+
|  /bmi-app/db-host      | bmi-aurora-cluster.cluster-xxxxx.ap-south-1.rds.amazonaws.com |
+------------------------+---------------------------------+
```

---

### Step 4.2: Create Database Name Parameter

**AWS Console:**
1. Click **Create parameter**
2. Configure:
   - **Name**: `/bmi-app/db-name`
   - **Description**: `Database name`
   - **Type**: `String`
   - **Value**: `bmidb`
3. Click **Create parameter**

**AWS CLI:**

```powershell
aws ssm put-parameter `
    --name "/bmi-app/db-name" `
    --description "Database name" `
    --value "bmidb" `
    --type String `
    --region ap-south-1
```

---

### Step 4.3: Create Database User Parameter

**AWS Console:**
1. Click **Create parameter**
2. Configure:
   - **Name**: `/bmi-app/db-user`
   - **Description**: `Database master username`
   - **Type**: `String`
   - **Value**: `postgres`
3. Click **Create parameter**

**AWS CLI:**

```powershell
aws ssm put-parameter `
    --name "/bmi-app/db-user" `
    --description "Database master username" `
    --value "postgres" `
    --type String `
    --region ap-south-1
```

---

### Step 4.4: Create Database Password Parameter (SecureString)

**AWS Console:**
1. Click **Create parameter**
2. Configure:
   - **Name**: `/bmi-app/db-password`
   - **Description**: `Database master password (encrypted)`
   - **Tier**: `Standard`
   - **Type**: `SecureString` ⚠️ (for encryption)
   - **KMS key source**: `My current account`
   - **KMS Key ID**: Leave as `alias/aws/ssm` (default)
   - **Value**: `BMIApp2024Secure!` (same password from Phase 2)
3. Click **Create parameter**

**AWS CLI:**

```powershell
aws ssm put-parameter `
    --name "/bmi-app/db-password" `
    --description "Database master password (encrypted)" `
    --value "BMIApp2024Secure!" `
    --type SecureString `
    --region ap-south-1
```

### ✅ Verification Step 4.4

```powershell
# Verify parameter exists (value will be encrypted in output)
aws ssm get-parameter --name "/bmi-app/db-password" --region ap-south-1 --query 'Parameter.[Name,Type]' --output table

# Decrypt and verify (only if you have kms:Decrypt permission)
aws ssm get-parameter --name "/bmi-app/db-password" --with-decryption --region ap-south-1 --query 'Parameter.Value' --output text
```

**Expected output (with decryption):**
```
BMIApp2024Secure!
```

---

### Step 4.5: Create Backend ALB URL Parameter (Placeholder)

We'll create a placeholder now and update it after creating the backend ALB in Phase 7.

**AWS Console:**
1. Click **Create parameter**
2. Configure:
   - **Name**: `/bmi-app/backend-alb-url`
   - **Description**: `Backend internal ALB URL (will be updated after ALB creation)`
   - **Type**: `String`
   - **Value**: `http://placeholder` ⚠️ (temporary - will update in Phase 7.3)
3. Click **Create parameter**

**AWS CLI:**

```powershell
aws ssm put-parameter `
    --name "/bmi-app/backend-alb-url" `
    --description "Backend internal ALB URL" `
    --value "http://placeholder" `
    --type String `
    --region ap-south-1
```

### ⚠️ Important Reminder
**You MUST update `/bmi-app/backend-alb-url` in Phase 7.3 after creating the backend ALB!**

---

### ✅ Phase 4 Complete Verification

List all parameters to ensure they're created correctly:

```powershell
# List all BMI app parameters
aws ssm get-parameters-by-path --path "/bmi-app" --region ap-south-1 --query 'Parameters[*].[Name,Type,Value]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|                  GetParametersByPath                     |
+----------------------------+-------------+---------------+
|  /bmi-app/backend-alb-url  |  String     | http://placeholder |
|  /bmi-app/db-host          |  String     | bmi-aurora-cluster.cluster-xxxxx.ap-south-1.rds.amazonaws.com |
|  /bmi-app/db-name          |  String     | bmidb         |
|  /bmi-app/db-password      |  SecureString| <encrypted>  |
|  /bmi-app/db-user          |  String     | postgres      |
+----------------------------+-------------+---------------+
```

**Test IAM permissions (simulate EC2 instance access):**

```powershell
# Test retrieving database password with decryption
aws ssm get-parameter --name "/bmi-app/db-password" --with-decryption --region ap-south-1 --query 'Parameter.Value' --output text
```

**Success criteria:**
- ✅ All 5 parameters created in `/bmi-app/` path
- ✅ `db-password` is type **SecureString** (encrypted)
- ✅ `db-host` contains correct Aurora endpoint
- ✅ `backend-alb-url` has placeholder (will update later)
- ✅ Can retrieve and decrypt SecureString parameter

**If all checks pass, proceed to Phase 5.** ✅

---

## Phase 5: Security Groups Setup (5 minutes)

### Overview
Create 6 security groups for network segmentation:
1. Frontend ALB (public-facing)
2. Frontend EC2 instances
3. Backend ALB (internal)
4. Backend EC2 instances
5. Aurora database (already created in Phase 2)
6. SSM endpoints (already created in Phase 1)

### Step 5.1: Create Frontend ALB Security Group

**AWS Console Steps:**
1. Navigate to **EC2** → **Security Groups**
2. Click **Create security group**
3. Configure:
   - **Security group name**: `frontend-alb-sg`
   - **Description**: `Security group for Frontend public ALB`
   - **VPC**: Select `devops-vpc`
4. **Inbound rules:**
   - Click **Add rule**
   - **Type**: `HTTP` (port 80)
   - **Source**: `Anywhere-IPv4` (0.0.0.0/0)
   - **Description**: `Allow HTTP from internet`
   - Click **Add rule** again
   - **Type**: `HTTPS` (port 443)
   - **Source**: `Anywhere-IPv4` (0.0.0.0/0)
   - **Description**: `Allow HTTPS from internet`
5. **Outbound rules:** Leave default (All traffic)
6. Click **Create security group**
7. **Note the Security Group ID**

**AWS CLI (Alternative):**

```powershell
# Create frontend ALB security group
aws ec2 create-security-group `
    --group-name frontend-alb-sg `
    --description "Security group for Frontend public ALB" `
    --vpc-id $vpcId `
    --region ap-south-1

# Get security group ID
$frontendAlbSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=frontend-alb-sg" "Name=vpc-id,Values=$vpcId" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Add HTTP rule
aws ec2 authorize-security-group-ingress `
    --group-id $frontendAlbSgId `
    --protocol tcp `
    --port 80 `
    --cidr 0.0.0.0/0 `
    --region ap-south-1

# Add HTTPS rule
aws ec2 authorize-security-group-ingress `
    --group-id $frontendAlbSgId `
    --protocol tcp `
    --port 443 `
    --cidr 0.0.0.0/0 `
    --region ap-south-1
```

### ✅ Verification Step 5.1

```powershell
aws ec2 describe-security-groups --group-names frontend-alb-sg --region ap-south-1 --query 'SecurityGroups[0].[GroupId,GroupName,IpPermissions[*].[FromPort,ToPort]]' --output table
```

**Expected:** Ports 80 and 443 open to 0.0.0.0/0

---

### Step 5.2: Create Frontend EC2 Security Group

**AWS Console:**
1. Click **Create security group**
2. Configure:
   - **Security group name**: `frontend-ec2-sg`
   - **Description**: `Security group for Frontend EC2 instances`
   - **VPC**: `devops-vpc`
3. **Inbound rules:**
   - **Type**: `HTTP` (80)
   - **Source**: `Custom` → Search and select `frontend-alb-sg`
   - **Description**: `Allow HTTP from Frontend ALB`
   - Click **Add rule**
   - **Type**: `HTTPS` (443)
   - **Source**: `Custom` → `10.0.0.0/16`
   - **Description**: `Allow HTTPS within VPC for inter-service communication`
4. Click **Create security group**

**AWS CLI:**

```powershell
# Create frontend EC2 security group
aws ec2 create-security-group `
    --group-name frontend-ec2-sg `
    --description "Security group for Frontend EC2 instances" `
    --vpc-id $vpcId `
    --region ap-south-1

$frontendEc2SgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=frontend-ec2-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Allow HTTP from frontend ALB security group
aws ec2 authorize-security-group-ingress `
    --group-id $frontendEc2SgId `
    --protocol tcp `
    --port 80 `
    --source-group $frontendAlbSgId `
    --region ap-south-1

# Allow HTTPS from VPC
aws ec2 authorize-security-group-ingress `
    --group-id $frontendEc2SgId `
    --protocol tcp `
    --port 443 `
    --cidr 10.0.0.0/16 `
    --region ap-south-1
```

### ✅ Verification Step 5.2

```powershell
aws ec2 describe-security-groups --group-names frontend-ec2-sg --region ap-south-1 --query 'SecurityGroups[0].[GroupId,IpPermissions[*].[FromPort,UserIdGroupPairs[0].GroupId,IpRanges[0].CidrIp]]' --output json
```

**Expected:** Port 80 from frontend-alb-sg, Port 443 from 10.0.0.0/16

---

### Step 5.3: Create Backend ALB Security Group

**AWS Console:**
1. Click **Create security group**
2. Configure:
   - **Security group name**: `backend-alb-sg`
   - **Description**: `Security group for Backend internal ALB`
   - **VPC**: `devops-vpc`
3. **Inbound rules:**
   - **Type**: `HTTP` (80)
   - **Source**: `Custom` → Search and select `frontend-ec2-sg`
   - **Description**: `Allow HTTP from Frontend EC2 instances`
4. Click **Create security group**

**AWS CLI:**

```powershell
# Create backend ALB security group
aws ec2 create-security-group `
    --group-name backend-alb-sg `
    --description "Security group for Backend internal ALB" `
    --vpc-id $vpcId `
    --region ap-south-1

$backendAlbSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=backend-alb-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Allow HTTP from frontend EC2 security group
aws ec2 authorize-security-group-ingress `
    --group-id $backendAlbSgId `
    --protocol tcp `
    --port 80 `
    --source-group $frontendEc2SgId `
    --region ap-south-1
```

### ✅ Verification Step 5.3

```powershell
aws ec2 describe-security-groups --group-names backend-alb-sg --region ap-south-1 --query 'SecurityGroups[0].[GroupName,IpPermissions[0].[FromPort,UserIdGroupPairs[0].GroupId]]' --output table
```

---

### Step 5.4: Create Backend EC2 Security Group

**AWS Console:**
1. Click **Create security group**
2. Configure:
   - **Security group name**: `backend-ec2-sg`
   - **Description**: `Security group for Backend EC2 instances`
   - **VPC**: `devops-vpc`
3. **Inbound rules:**
   - **Type**: `Custom TCP`
   - **Port range**: `3000`
   - **Source**: `Custom` → Search and select `backend-alb-sg`
   - **Description**: `Allow Node.js app port from Backend ALB`
4. Click **Create security group**

**AWS CLI:**

```powershell
# Create backend EC2 security group
aws ec2 create-security-group `
    --group-name backend-ec2-sg `
    --description "Security group for Backend EC2 instances" `
    --vpc-id $vpcId `
    --region ap-south-1

$backendEc2SgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=backend-ec2-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Allow port 3000 from backend ALB security group
aws ec2 authorize-security-group-ingress `
    --group-id $backendEc2SgId `
    --protocol tcp `
    --port 3000 `
    --source-group $backendAlbSgId `
    --region ap-south-1
```

### ✅ Verification Step 5.4

```powershell
aws ec2 describe-security-groups --group-names backend-ec2-sg --region ap-south-1 --query 'SecurityGroups[0].[GroupName,IpPermissions[0].[FromPort,UserIdGroupPairs[0].GroupId]]' --output table
```

**Expected:** Port 3000 from backend-alb-sg

---

### Step 5.5: Update Aurora Security Group

Update the Aurora security group created in Phase 2 to only allow traffic from backend EC2 instances.

**AWS Console:**
1. Go to **Security Groups** → Find `aurora-sg`
2. Select it and go to **Inbound rules** tab
3. Click **Edit inbound rules**
4. **Delete** the existing rule (allowing from 10.0.0.0/16)
5. Click **Add rule**:
   - **Type**: `PostgreSQL` (5432)
   - **Source**: `Custom` → Search and select `backend-ec2-sg`
   - **Description**: `Allow PostgreSQL from Backend EC2 instances only`
6. Click **Save rules**

**AWS CLI:**

```powershell
# Get Aurora security group ID
$auroraSgId = (aws ec2 describe-security-groups --group-names aurora-sg --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Remove old rule (allowing from VPC CIDR)
aws ec2 revoke-security-group-ingress `
    --group-id $auroraSgId `
    --protocol tcp `
    --port 5432 `
    --cidr 10.0.0.0/16 `
    --region ap-south-1

# Add new rule (allowing only from backend EC2 security group)
aws ec2 authorize-security-group-ingress `
    --group-id $auroraSgId `
    --protocol tcp `
    --port 5432 `
    --source-group $backendEc2SgId `
    --region ap-south-1
```

### ✅ Verification Step 5.5

```powershell
aws ec2 describe-security-groups --group-names aurora-sg --region ap-south-1 --query 'SecurityGroups[0].[GroupName,IpPermissions[0].[FromPort,UserIdGroupPairs[0].GroupId]]' --output table
```

**Expected:** Port 5432 from backend-ec2-sg (not from CIDR)

---

### ✅ Phase 5 Complete Verification

Verify the complete security group chain:

```powershell
Write-Host "=== Security Groups Verification ===" -ForegroundColor Green

# List all BMI security groups
$sgList = @('frontend-alb-sg', 'frontend-ec2-sg', 'backend-alb-sg', 'backend-ec2-sg', 'aurora-sg', 'ssm-endpoint-sg')

foreach ($sgName in $sgList) {
    $sgId = aws ec2 describe-security-groups --filters "Name=group-name,Values=$sgName" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text
    Write-Host "✅ $sgName : $sgId"
}
```

**Traffic flow verification:**
```
Internet (0.0.0.0/0) 
  → frontend-alb-sg (80, 443)
    → frontend-ec2-sg (80)
      → backend-alb-sg (80)
        → backend-ec2-sg (3000)
          → aurora-sg (5432)
```

**Success criteria:**
- ✅ All 6 security groups exist
- ✅ Frontend ALB allows internet access (0.0.0.0/0)
- ✅ Each layer only accepts traffic from the previous layer
- ✅ Aurora only accepts traffic from backend EC2 instances
- ✅ No direct internet access to EC2 instances or database

**If all checks pass, proceed to Phase 6.** ✅

---

## Phase 6: Create Golden AMIs (20 minutes)

### Overview
Create pre-configured AMIs (Amazon Machine Images) with all dependencies installed. This speeds up instance launch time and ensures consistency.

**Why Golden AMIs?**
- ⚡ Faster deployments (5-7 min vs 15-20 min)
- 🔄 Consistent environment across all instances
- 📦 Pre-installed: Node.js 20, PM2, nginx, PostgreSQL client

### Step 6.1: Launch Temporary Backend Instance for AMI Creation

**AWS Console Steps:**
1. Navigate to **EC2** → **Instances**
2. Click **Launch instances**
3. Configure:
   - **Name**: `backend-golden-ami-temp`
   - **Application and OS Images (Amazon Machine Image)**:
     - Click **Browse more AMIs**
     - Search for `Amazon Linux 2023 AMI`
     - Select the latest **Amazon Linux 2023 AMI** (HVM, SSD Volume Type)
     - **Architecture**: `64-bit (x86)`
   - **Instance type**: `t3.micro`
   - **Key pair**: You can select existing or proceed without key pair (we'll use SSM)
   - **Network settings**:
     - **VPC**: `devops-vpc`
     - **Subnet**: Select `devops-subnet-public1-ap-south-1a` ⚠️ (public for initial setup)
     - **Auto-assign public IP**: `Enable` ⚠️ (needed for downloading packages)
     - **Firewall (security groups)**: Create new security group
       - **Security group name**: `temp-ami-creation-sg`
       - **Description**: `Temporary SG for Golden AMI creation`
       - **Inbound rules**: Add SSH (22) from your IP (optional, we'll use SSM)
   - **Advanced details**:
     - **IAM instance profile**: Select `EC2RoleForBMIApp`
4. Click **Launch instance**
5. Wait ~2 minutes for instance to be **Running** and **2/2 checks passed**

### ✅ Verification Step 6.1

```powershell
# Check instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=backend-golden-ami-temp" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress]' --output table
```

**Expected output:**
```
------------------------------------------------------
|              DescribeInstances                     |
+---------------------+-----------+------------------+
|  i-xxxxxxxxxxxxxxxxx| running   | 13.xx.xx.xx     |
+---------------------+-----------+------------------+
```

**Success criteria:**
- ✅ Instance state is **running**
- ✅ Has public IP address
- ✅ Status checks: 2/2 passed (wait a couple minutes if initializing)

---

### Step 6.2: Connect and Setup Backend AMI

**Connect via AWS Systems Manager Session Manager:**

**AWS Console:**
1. Go to **EC2** → **Instances**
2. Select `backend-golden-ami-temp`
3. Click **Connect** button
4. Select **Session Manager** tab
5. Click **Connect**

**AWS CLI (Alternative):**

```powershell
# Get instance ID
$backendTempInstanceId = (aws ec2 describe-instances --filters "Name=tag:Name,Values=backend-golden-ami-temp" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Start SSM session
aws ssm start-session --target $backendTempInstanceId --region ap-south-1
```

**Once connected, run the backend setup script:**

```bash
# Download the backend userdata script
curl -o backend-userdata.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/backend-userdata.sh

# Make it executable
chmod +x backend-userdata.sh

# Run the setup script (takes ~5 minutes)
sudo ./backend-userdata.sh
```

**The script will install:**
- ✅ System updates (dnf update)
- ✅ Node.js 20 (LTS version for Amazon Linux 2023)
- ✅ PM2 (process manager for Node.js)
- ✅ PostgreSQL 15 client (for running migrations)
- ✅ Git
- ✅ CloudWatch agent

### ⏱️ Wait Time: 5-7 minutes for installation

### ✅ Verification Step 6.2

After the script completes, verify installations:

```bash
# Check Node.js version (should be v20.x)
node --version

# Check NPM version
npm --version

# Check PM2 installed globally
pm2 --version

# Check PostgreSQL client (should be 15.x)
psql --version

# Check git
git --version

# Verify dnf package manager (Amazon Linux 2023)
dnf --version
```

**Expected outputs:**
```
v20.11.0 (or similar 20.x version)
10.x.x
5.x.x
psql (PostgreSQL) 15.x
git version 2.x.x
4.x.x
```

**Success criteria:**
- ✅ Node.js version is 20.x
- ✅ PM2 is installed globally
- ✅ PostgreSQL 15 client is available
- ✅ Git is installed
- ✅ No errors during installation

**Exit the SSM session:**
```bash
exit
```

---

### Step 6.3: Create Backend AMI

**AWS Console:**
1. Go to **EC2** → **Instances**
2. Select `backend-golden-ami-temp`
3. Click **Actions** → **Image and templates** → **Create image**
4. Configure:
   - **Image name**: `bmi-backend-golden-ami`
   - **Image description**: `Golden AMI for BMI Backend with Node.js 20, PM2, PostgreSQL 15 client (Amazon Linux 2023)`
   - **No reboot**: Leave **unchecked** (recommended for consistency)
5. Click **Create image**
6. Go to **Images** → **AMIs** in the left sidebar
7. Wait ~3-5 minutes for AMI status to change to **available**
8. **Note the AMI ID** (e.g., `ami-xxxxxxxxxxxxxxxxx`)

**AWS CLI:**

```powershell
# Create AMI from the temporary instance
$backendAmiId = aws ec2 create-image `
    --instance-id $backendTempInstanceId `
    --name "bmi-backend-golden-ami" `
    --description "Golden AMI for BMI Backend with Node.js 20, PM2, PostgreSQL 15 (Amazon Linux 2023)" `
    --region ap-south-1 `
    --query 'ImageId' `
    --output text

Write-Host "Backend AMI ID: $backendAmiId" -ForegroundColor Yellow
Write-Host "Waiting for AMI to be available..."

# Wait for AMI to be available
aws ec2 wait image-available --image-ids $backendAmiId --region ap-south-1

Write-Host "✅ Backend AMI is ready!" -ForegroundColor Green
```

### ✅ Verification Step 6.3

```powershell
# Check AMI status
aws ec2 describe-images --image-ids $backendAmiId --region ap-south-1 --query 'Images[0].[ImageId,Name,State,Description]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|                     DescribeImages                       |
+-----------------------+----------------+-----------------+
| ami-xxxxxxxxxxxxxxxxx | bmi-backend-golden-ami | available | Golden AMI for BMI Backend... |
+-----------------------+----------------+-----------------+
```

**Success criteria:**
- ✅ AMI state is **available**
- ✅ AMI ID is saved for later use
- ✅ Based on Amazon Linux 2023

---

### Step 6.4: Launch Temporary Frontend Instance for AMI Creation

**AWS Console:**
1. Click **Launch instances**
2. Configure:
   - **Name**: `frontend-golden-ami-temp`
   - **Amazon Machine Image**: `Amazon Linux 2023 AMI` (latest)
   - **Instance type**: `t3.micro`
   - **Key pair**: Same as before (or none)
   - **Network settings**:
     - **VPC**: `devops-vpc`
     - **Subnet**: `devops-subnet-public1-ap-south-1a` (public)
     - **Auto-assign public IP**: `Enable`
     - **Security group**: Select `temp-ami-creation-sg` (from Step 6.1)
   - **Advanced details**:
     - **IAM instance profile**: `EC2RoleForBMIApp`
3. Click **Launch instance**
4. Wait for **Running** state

### ✅ Verification Step 6.4

```powershell
# Check frontend temp instance
aws ec2 describe-instances --filters "Name=tag:Name,Values=frontend-golden-ami-temp" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[0].Instances[0].[InstanceId,State.Name]' --output table
```

---

### Step 6.5: Connect and Setup Frontend AMI

**Connect via Session Manager:**

```powershell
# Get instance ID
$frontendTempInstanceId = (aws ec2 describe-instances --filters "Name=tag:Name,Values=frontend-golden-ami-temp" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Start SSM session
aws ssm start-session --target $frontendTempInstanceId --region ap-south-1
```

**Once connected, run the frontend setup script:**

```bash
# Download frontend userdata script
curl -o frontend-userdata.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/frontend-userdata.sh

# Make executable
chmod +x frontend-userdata.sh

# Run setup (takes ~5 minutes)
sudo ./frontend-userdata.sh
```

**The script will install:**
- ✅ System updates
- ✅ Nginx (web server)
- ✅ Node.js 20 (for building React app)
- ✅ Git
- ✅ CloudWatch agent

### ⏱️ Wait Time: 5-7 minutes

### ✅ Verification Step 6.5

```bash
# Verify installations
node --version   # Should be v20.x
npm --version    # Should be 10.x
nginx -v         # Should be nginx/1.x
git --version

# Check nginx is running
sudo systemctl status nginx

# Check nginx is enabled on boot
sudo systemctl is-enabled nginx
```

**Expected:**
```
v20.11.0
10.x.x
nginx version: nginx/1.24.0 (or similar)
git version 2.x.x
● nginx.service - The nginx HTTP and reverse proxy server
   Active: active (running)
enabled
```

**Success criteria:**
- ✅ Node.js 20.x installed
- ✅ Nginx installed and running
- ✅ Nginx enabled on boot
- ✅ Git installed

**Exit session:**
```bash
exit
```

---

### Step 6.6: Create Frontend AMI

**AWS Console:**
1. Select `frontend-golden-ami-temp`
2. **Actions** → **Image and templates** → **Create image**
3. Configure:
   - **Image name**: `bmi-frontend-golden-ami`
   - **Image description**: `Golden AMI for BMI Frontend with nginx, Node.js 20 (Amazon Linux 2023)`
   - **No reboot**: Leave unchecked
4. Click **Create image**
5. Wait ~3-5 minutes for status **available**

**AWS CLI:**

```powershell
# Create frontend AMI
$frontendAmiId = aws ec2 create-image `
    --instance-id $frontendTempInstanceId `
    --name "bmi-frontend-golden-ami" `
    --description "Golden AMI for BMI Frontend with nginx, Node.js 20 (Amazon Linux 2023)" `
    --region ap-south-1 `
    --query 'ImageId' `
    --output text

Write-Host "Frontend AMI ID: $frontendAmiId" -ForegroundColor Yellow

# Wait for AMI
aws ec2 wait image-available --image-ids $frontendAmiId --region ap-south-1
Write-Host "✅ Frontend AMI is ready!" -ForegroundColor Green
```

### ✅ Verification Step 6.6

```powershell
aws ec2 describe-images --image-ids $frontendAmiId --region ap-south-1 --query 'Images[0].[ImageId,Name,State]' --output table
```

**Expected:** State is **available**

---

### Step 6.7: Terminate Temporary Instances

Now that AMIs are created, terminate the temporary instances to save costs.

**AWS Console:**
1. Go to **EC2** → **Instances**
2. Select both:
   - `backend-golden-ami-temp`
   - `frontend-golden-ami-temp`
3. Click **Instance state** → **Terminate instance**
4. Confirm termination

**AWS CLI:**

```powershell
# Terminate both temporary instances
aws ec2 terminate-instances `
    --instance-ids $backendTempInstanceId $frontendTempInstanceId `
    --region ap-south-1

Write-Host "✅ Temporary instances terminated" -ForegroundColor Green
```

### ✅ Verification Step 6.7

```powershell
# Verify instances are terminating/terminated
aws ec2 describe-instances --instance-ids $backendTempInstanceId $frontendTempInstanceId --region ap-south-1 --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table
```

**Expected:** State is **shutting-down** or **terminated**

---

### ✅ Phase 6 Complete Verification

```powershell
Write-Host "=== Phase 6 Golden AMIs Verification ===" -ForegroundColor Green

# List both AMIs
aws ec2 describe-images --owners self --filters "Name=name,Values=bmi-*-golden-ami" --region ap-south-1 --query 'Images[*].[ImageId,Name,State,CreationDate]' --output table

# Save AMI IDs for later use
$backendAmiId = (aws ec2 describe-images --owners self --filters "Name=name,Values=bmi-backend-golden-ami" --region ap-south-1 --query 'Images[0].ImageId' --output text)
$frontendAmiId = (aws ec2 describe-images --owners self --filters "Name=name,Values=bmi-frontend-golden-ami" --region ap-south-1 --query 'Images[0].ImageId' --output text)

Write-Host "`n✅ Backend AMI: $backendAmiId" -ForegroundColor Yellow
Write-Host "✅ Frontend AMI: $frontendAmiId" -ForegroundColor Yellow

# Verify temporary instances are terminated
$tempInstances = aws ec2 describe-instances --filters "Name=tag:Name,Values=*golden-ami-temp" --region ap-south-1 --query 'Reservations[*].Instances[*].State.Name' --output text
Write-Host "✅ Temp instances state: $tempInstances" -ForegroundColor Green
```

**Success criteria:**
- ✅ Backend AMI available with Node.js 20, PM2, PostgreSQL 15
- ✅ Frontend AMI available with nginx, Node.js 20
- ✅ Both AMIs based on Amazon Linux 2023
- ✅ Temporary instances terminated
- ✅ AMI IDs saved for use in Phase 8 and 9

**What's inside the AMIs:**
- **Backend AMI:**
  - Amazon Linux 2023 (dnf package manager)
  - Node.js 20.x LTS
  - PM2 5.x (cluster mode ready)
  - PostgreSQL 15 client (for migrations)
  - Git, CloudWatch agent
  
- **Frontend AMI:**
  - Amazon Linux 2023 (dnf package manager)
  - Node.js 20.x LTS (for React build)
  - Nginx 1.24.x (configured and enabled)
  - Git, CloudWatch agent

**If all checks pass, proceed to Phase 7.** ✅

---

## Phase 7: Application Load Balancers (10 minutes)

### Overview
Create two Application Load Balancers:
1. **Backend ALB** (Internal) - Routes traffic from frontend to backend EC2
2. **Frontend ALB** (Public) - Routes internet traffic to frontend EC2

### Step 7.1: Create Backend Target Group

**AWS Console Steps:**
1. Navigate to **EC2** → **Target Groups**
2. Click **Create target group**
3. **Choose a target type**:
   - Select **Instances**
   - Click **Next**
4. **Specify group details:**
   - **Target group name**: `bmi-backend-tg`
   - **Protocol**: `HTTP`
   - **Port**: `3000` ⚠️ (Node.js app port)
   - **IP address type**: `IPv4`
   - **VPC**: Select `devops-vpc`
   - **Protocol version**: `HTTP1`
5. **Health checks:**
   - **Health check protocol**: `HTTP`
   - **Health check path**: `/health`
   - **Advanced health check settings**:
     - **Port**: `Traffic port`
     - **Healthy threshold**: `2` consecutive checks
     - **Unhealthy threshold**: `3` consecutive checks
     - **Timeout**: `5` seconds
     - **Interval**: `10` seconds
     - **Success codes**: `200`
6. Click **Next**
7. **Register targets**: Don't register any yet (we'll do this after launching backend EC2)
8. Click **Create target group**

**AWS CLI (Alternative):**

```powershell
# Create backend target group
aws elbv2 create-target-group `
    --name bmi-backend-tg `
    --protocol HTTP `
    --port 3000 `
    --vpc-id $vpcId `
    --health-check-protocol HTTP `
    --health-check-path /health `
    --health-check-interval-seconds 10 `
    --health-check-timeout-seconds 5 `
    --healthy-threshold-count 2 `
    --unhealthy-threshold-count 3 `
    --matcher HttpCode=200 `
    --region ap-south-1
```

### ✅ Verification Step 7.1

```powershell
# Verify backend target group
aws elbv2 describe-target-groups --names bmi-backend-tg --region ap-south-1 --query 'TargetGroups[0].[TargetGroupName,Protocol,Port,HealthCheckPath]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|                DescribeTargetGroups                      |
+-------------------+----------+-------+------------------+
|  bmi-backend-tg   |  HTTP    | 3000  | /health          |
+-------------------+----------+-------+------------------+
```

---

### Step 7.2: Create Backend ALB (Internal)

**AWS Console Steps:**
1. Navigate to **EC2** → **Load Balancers**
2. Click **Create load balancer**
3. Select **Application Load Balancer** → **Create**
4. **Basic configuration:**
   - **Load balancer name**: `bmi-backend-alb`
   - **Scheme**: `Internal` ⚠️ (not internet-facing!)
   - **IP address type**: `IPv4`
5. **Network mapping:**
   - **VPC**: Select `devops-vpc`
   - **Mappings**: Select **both AZs**:
     - **ap-south-1a**: Select `devops-subnet-private1-ap-south-1a` ⚠️ (private!)
     - **ap-south-1b**: Select `devops-subnet-private2-ap-south-1b` ⚠️ (private!)
6. **Security groups:**
   - Remove default security group
   - Select `backend-alb-sg`
7. **Listeners and routing:**
   - **Protocol**: `HTTP`
   - **Port**: `80`
   - **Default action**: Forward to `bmi-backend-tg`
8. **Load balancer tags** (optional):
   - Key: `Name`, Value: `bmi-backend-alb`
9. Click **Create load balancer**
10. Wait ~2 minutes for state to become **active**
11. **Copy the DNS name** - You'll need this for Parameter Store!

**AWS CLI:**

```powershell
# Get private subnet IDs (if not already saved)
$privateSubnet1 = (aws ec2 describe-subnets --filters "Name=tag:Name,Values=devops-subnet-private1-ap-south-1a" --region ap-south-1 --query 'Subnets[0].SubnetId' --output text)
$privateSubnet2 = (aws ec2 describe-subnets --filters "Name=tag:Name,Values=devops-subnet-private2-ap-south-1b" --region ap-south-1 --query 'Subnets[0].SubnetId' --output text)

# Get backend ALB security group ID
$backendAlbSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=backend-alb-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Get backend target group ARN
$backendTgArn = (aws elbv2 describe-target-groups --names bmi-backend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Create internal backend ALB
$backendAlbArn = aws elbv2 create-load-balancer `
    --name bmi-backend-alb `
    --scheme internal `
    --type application `
    --subnets $privateSubnet1 $privateSubnet2 `
    --security-groups $backendAlbSgId `
    --region ap-south-1 `
    --query 'LoadBalancers[0].LoadBalancerArn' `
    --output text

# Create listener
aws elbv2 create-listener `
    --load-balancer-arn $backendAlbArn `
    --protocol HTTP `
    --port 80 `
    --default-actions Type=forward,TargetGroupArn=$backendTgArn `
    --region ap-south-1

# Get DNS name
$backendAlbDns = (aws elbv2 describe-load-balancers --load-balancer-arns $backendAlbArn --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
Write-Host "✅ Backend ALB DNS: $backendAlbDns" -ForegroundColor Yellow
```

### ✅ Verification Step 7.2

```powershell
# Check backend ALB status
aws elbv2 describe-load-balancers --names bmi-backend-alb --region ap-south-1 --query 'LoadBalancers[0].[LoadBalancerName,State.Code,Scheme,DNSName]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|               DescribeLoadBalancers                      |
+-------------------+--------+----------+------------------+
| bmi-backend-alb   | active | internal | internal-bmi-backend-alb-xxxxx.ap-south-1.elb.amazonaws.com |
+-------------------+--------+----------+------------------+
```

**Success criteria:**
- ✅ State is **active**
- ✅ Scheme is **internal**
- ✅ DNS name contains `internal-` prefix
- ✅ DNS name ends with `.ap-south-1.elb.amazonaws.com`

**Save the Backend ALB DNS name:**
```powershell
$backendAlbDns = (aws elbv2 describe-load-balancers --names bmi-backend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
Write-Host "Backend ALB DNS (save this!): http://$backendAlbDns" -ForegroundColor Yellow
```

---

### Step 7.3: ⚠️ Update Parameter Store with Backend ALB URL

**This is critical!** Update the placeholder parameter we created in Phase 4.

**AWS Console:**
1. Navigate to **Systems Manager** → **Parameter Store**
2. Find and click `/bmi-app/backend-alb-url`
3. Click **Edit**
4. Update **Value** to: `http://<backend-alb-dns-name>`
   - Example: `http://internal-bmi-backend-alb-123456789.ap-south-1.elb.amazonaws.com`
   - ⚠️ Include `http://` prefix!
   - ⚠️ DO NOT add trailing slash!
5. Click **Save changes**

**AWS CLI:**

```powershell
# Update backend ALB URL parameter
aws ssm put-parameter `
    --name "/bmi-app/backend-alb-url" `
    --value "http://$backendAlbDns" `
    --type String `
    --overwrite `
    --region ap-south-1

Write-Host "✅ Parameter Store updated with backend ALB URL" -ForegroundColor Green
```

### ✅ Verification Step 7.3

```powershell
# Verify the parameter was updated correctly
$backendUrl = aws ssm get-parameter --name "/bmi-app/backend-alb-url" --region ap-south-1 --query 'Parameter.Value' --output text
Write-Host "Backend ALB URL in Parameter Store: $backendUrl" -ForegroundColor Cyan

# Should start with http:// and not be placeholder
if ($backendUrl -match "^http://" -and $backendUrl -notmatch "placeholder") {
    Write-Host "✅ Backend ALB URL correctly configured!" -ForegroundColor Green
} else {
    Write-Host "❌ ERROR: Backend ALB URL is incorrect! Update it manually." -ForegroundColor Red
}
```

---

### Step 7.4: Create Frontend Target Group

**AWS Console:**
1. Click **Create target group**
2. Configure:
   - **Target type**: `Instances`
   - **Target group name**: `bmi-frontend-tg`
   - **Protocol**: `HTTP`
   - **Port**: `80` ⚠️ (nginx port)
   - **VPC**: `devops-vpc`
3. **Health checks:**
   - **Health check protocol**: `HTTP`
   - **Health check path**: `/health`
   - **Interval**: `10` seconds
   - **Timeout**: `5` seconds
   - **Healthy threshold**: `2`
   - **Unhealthy threshold**: `3`
   - **Success codes**: `200`
4. Click **Next**
5. Don't register targets yet
6. Click **Create target group**

**AWS CLI:**

```powershell
aws elbv2 create-target-group `
    --name bmi-frontend-tg `
    --protocol HTTP `
    --port 80 `
    --vpc-id $vpcId `
    --health-check-protocol HTTP `
    --health-check-path /health `
    --health-check-interval-seconds 10 `
    --health-check-timeout-seconds 5 `
    --healthy-threshold-count 2 `
    --unhealthy-threshold-count 3 `
    --matcher HttpCode=200 `
    --region ap-south-1
```

### ✅ Verification Step 7.4

```powershell
aws elbv2 describe-target-groups --names bmi-frontend-tg --region ap-south-1 --query 'TargetGroups[0].[TargetGroupName,Protocol,Port,HealthCheckPath]' --output table
```

---

### Step 7.5: Create Frontend ALB (Public)

**AWS Console:**
1. Click **Create load balancer**
2. Select **Application Load Balancer**
3. **Basic configuration:**
   - **Load balancer name**: `bmi-frontend-alb`
   - **Scheme**: `Internet-facing` ⚠️ (public!)
   - **IP address type**: `IPv4`
4. **Network mapping:**
   - **VPC**: `devops-vpc`
   - **Mappings**: Select **both AZs**:
     - **ap-south-1a**: Select `devops-subnet-public1-ap-south-1a` ⚠️ (public!)
     - **ap-south-1b**: Select `devops-subnet-public2-ap-south-1b` ⚠️ (public!)
5. **Security groups:**
   - Remove default
   - Select `frontend-alb-sg`
6. **Listeners and routing:**
   - **Protocol**: `HTTP`
   - **Port**: `80`
   - **Default action**: Forward to `bmi-frontend-tg`
7. Click **Create load balancer**
8. Wait ~2 minutes for **active** state
9. **Copy the DNS name** - This is your application URL! 🎉

**AWS CLI:**

```powershell
# Get public subnet IDs
$publicSubnet1 = (aws ec2 describe-subnets --filters "Name=tag:Name,Values=devops-subnet-public1-ap-south-1a" --region ap-south-1 --query 'Subnets[0].SubnetId' --output text)
$publicSubnet2 = (aws ec2 describe-subnets --filters "Name=tag:Name,Values=devops-subnet-public2-ap-south-1b" --region ap-south-1 --query 'Subnets[0].SubnetId' --output text)

# Get frontend ALB security group ID
$frontendAlbSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=frontend-alb-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Get frontend target group ARN
$frontendTgArn = (aws elbv2 describe-target-groups --names bmi-frontend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Create internet-facing frontend ALB
$frontendAlbArn = aws elbv2 create-load-balancer `
    --name bmi-frontend-alb `
    --scheme internet-facing `
    --type application `
    --subnets $publicSubnet1 $publicSubnet2 `
    --security-groups $frontendAlbSgId `
    --region ap-south-1 `
    --query 'LoadBalancers[0].LoadBalancerArn' `
    --output text

# Create listener
aws elbv2 create-listener `
    --load-balancer-arn $frontendAlbArn `
    --protocol HTTP `
    --port 80 `
    --default-actions Type=forward,TargetGroupArn=$frontendTgArn `
    --region ap-south-1

# Get DNS name
$frontendAlbDns = (aws elbv2 describe-load-balancers --load-balancer-arns $frontendAlbArn --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
Write-Host "🎉 Frontend ALB DNS (Your app URL!): http://$frontendAlbDns" -ForegroundColor Green
```

### ✅ Verification Step 7.5

```powershell
# Check frontend ALB status
aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].[LoadBalancerName,State.Code,Scheme,DNSName]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|               DescribeLoadBalancers                      |
+-------------------+--------+-----------------+------------+
| bmi-frontend-alb  | active | internet-facing | bmi-frontend-alb-xxxxx.ap-south-1.elb.amazonaws.com |
+-------------------+--------+-----------------+------------+
```

**Success criteria:**
- ✅ State is **active**
- ✅ Scheme is **internet-facing**
- ✅ DNS name does NOT have `internal-` prefix
- ✅ Can access ALB (will show 503 until targets are registered)

**Test ALB accessibility:**
```powershell
# Try to access the frontend ALB (will return 503 until instances are registered)
curl -I http://$frontendAlbDns
```

**Expected:** HTTP 503 (no targets registered yet - that's normal!)

---

### ✅ Phase 7 Complete Verification

```powershell
Write-Host "=== Phase 7 Load Balancers Verification ===" -ForegroundColor Green

# Get both ALB DNS names
$backendAlbDns = (aws elbv2 describe-load-balancers --names bmi-backend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
$frontendAlbDns = (aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)

Write-Host "`n✅ Backend ALB (internal): http://$backendAlbDns" -ForegroundColor Yellow
Write-Host "✅ Frontend ALB (public): http://$frontendAlbDns" -ForegroundColor Cyan

# Verify both target groups
$tgCheck = aws elbv2 describe-target-groups --names bmi-backend-tg bmi-frontend-tg --region ap-south-1 --query 'TargetGroups[*].[TargetGroupName,Port,HealthCheckPath]' --output table
Write-Host "`nTarget Groups:"
Write-Host $tgCheck

# Verify Parameter Store has backend URL
$storedBackendUrl = aws ssm get-parameter --name "/bmi-app/backend-alb-url" --region ap-south-1 --query 'Parameter.Value' --output text
Write-Host "`n✅ Backend URL in Parameter Store: $storedBackendUrl" -ForegroundColor Green

Write-Host "`n✅ Phase 7 Complete!" -ForegroundColor Green
```

**Success criteria:**
- ✅ Backend ALB (internal) created and active
- ✅ Frontend ALB (internet-facing) created and active
- ✅ Both target groups created with correct health check paths
- ✅ Parameter Store updated with backend ALB URL
- ✅ Both ALBs in correct subnets (backend in private, frontend in public)

**Save these values:**
- **Frontend ALB URL** (your app): `http://<frontend-alb-dns>`
- **Backend ALB URL** (internal): `http://<backend-alb-dns>`

**If all checks pass, proceed to Phase 8.** ✅

---

## Phase 8: Backend EC2 Instances (Manual - Fixed 2 Instances) (10 minutes)

### Overview
Launch 2 backend EC2 instances manually (no auto-scaling) using the Golden AMI. These will run the Node.js Express API with PM2 in cluster mode.

### Step 8.1: Create Backend Deployment User Data Script

First, let's verify the deploy-backend.sh script will work with our setup:

```powershell
# Download and review the deployment script
curl -o deploy-backend.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/deploy-backend.sh

# Display the script (review it)
Get-Content deploy-backend.sh | Select-Object -First 30
```

**The script does:**
1. Fetches DB credentials from Parameter Store
2. Clones the GitHub repository
3. Installs npm dependencies
4. Creates .env file with database connection
5. Runs database migrations (with lock file to prevent duplicates)
6. Starts app with PM2 in cluster mode

---

### Step 8.2: Launch Backend Instance 1

**AWS Console Steps:**
1. Navigate to **EC2** → **Instances**
2. Click **Launch instances**
3. Configure:
   - **Name**: `bmi-backend-1`
   - **Application and OS Images**:
     - Click **My AMIs** tab
     - Select `bmi-backend-golden-ami` (created in Phase 6.3)
   - **Instance type**: `t3.micro`
   - **Key pair**: Select existing or **Proceed without a key pair** (using SSM)
   - **Network settings**:
     - **VPC**: `devops-vpc`
     - **Subnet**: Select `devops-subnet-private1-ap-south-1a` ⚠️ (private subnet!)
     - **Auto-assign public IP**: `Disable` ⚠️ (must be disabled for private subnet)
     - **Firewall (security groups)**: Select existing → `backend-ec2-sg`
   - **Advanced details**:
     - **IAM instance profile**: Select `EC2RoleForBMIApp`
     - **User data** (scroll down):

```bash
#!/bin/bash
# Backend deployment script - runs on first boot
curl -o /tmp/deploy-backend.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/deploy-backend.sh
chmod +x /tmp/deploy-backend.sh
/tmp/deploy-backend.sh
```

4. Click **Launch instance**

**AWS CLI (Alternative):**

```powershell
# Get backend AMI ID
$backendAmiId = (aws ec2 describe-images --owners self --filters "Name=name,Values=bmi-backend-golden-ami" --region ap-south-1 --query 'Images[0].ImageId' --output text)

# Get backend EC2 security group ID
$backendEc2SgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=backend-ec2-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Create user data script
$userData = @'
#!/bin/bash
curl -o /tmp/deploy-backend.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/deploy-backend.sh
chmod +x /tmp/deploy-backend.sh
/tmp/deploy-backend.sh
'@

# Encode user data to base64
$userDataBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userData))

# Launch backend instance 1
$backendInstance1 = aws ec2 run-instances `
    --image-id $backendAmiId `
    --instance-type t3.micro `
    --subnet-id $privateSubnet1 `
    --security-group-ids $backendEc2SgId `
    --iam-instance-profile Name=EC2RoleForBMIApp `
    --user-data $userData `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=bmi-backend-1}]" `
    --region ap-south-1 `
    --query 'Instances[0].InstanceId' `
    --output text

Write-Host "✅ Backend Instance 1 ID: $backendInstance1" -ForegroundColor Green
```

### ⏱️ Wait Time: 5-7 minutes for deployment

The instance needs time to:
1. Boot up (~2 min)
2. Run user data script (~5 min):
   - Clone repo
   - Install npm packages
   - Run migrations
   - Start PM2

---

### Step 8.3: Launch Backend Instance 2

**AWS Console:**
1. Repeat Step 8.2 with these changes:
   - **Name**: `bmi-backend-2`
   - **Subnet**: Select `devops-subnet-private2-ap-south-1b` ⚠️ (different AZ!)
   - Same AMI, instance type, security group, IAM role, and user data
2. Click **Launch instance**

**AWS CLI:**

```powershell
# Launch backend instance 2 in different AZ
$backendInstance2 = aws ec2 run-instances `
    --image-id $backendAmiId `
    --instance-type t3.micro `
    --subnet-id $privateSubnet2 `
    --security-group-ids $backendEc2SgId `
    --iam-instance-profile Name=EC2RoleForBMIApp `
    --user-data $userData `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=bmi-backend-2}]" `
    --region ap-south-1 `
    --query 'Instances[0].InstanceId' `
    --output text

Write-Host "✅ Backend Instance 2 ID: $backendInstance2" -ForegroundColor Green
```

### ✅ Verification Step 8.3

```powershell
# Check both backend instances are running
aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-*" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PrivateIpAddress,SubnetId]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|                   DescribeInstances                      |
+---------------------+----------------+----------+----------+
| i-xxxxxxxxxxxxxxxxx | bmi-backend-1  | running  | 10.0.128.x | subnet-xxx |
| i-yyyyyyyyyyyyyyyyy | bmi-backend-2  | running  | 10.0.144.x | subnet-yyy |
+---------------------+----------------+----------+----------+
```

**Success criteria:**
- ✅ Both instances in **running** state
- ✅ Different private IPs
- ✅ Different subnets (different AZs)
- ✅ No public IPs (private subnet)

---

### Step 8.4: Monitor Backend Deployment

**Check deployment logs via SSM Session Manager:**

```powershell
# Connect to backend instance 1
$backendInstance1 = (aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-1" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Start SSM session
aws ssm start-session --target $backendInstance1 --region ap-south-1
```

**Once connected, check deployment logs:**

```bash
# Check deployment log
sudo tail -f /var/log/backend-deploy.log

# Or if log doesn't exist yet, check cloud-init logs
sudo tail -f /var/log/cloud-init-output.log

# Check PM2 status (after deployment completes)
pm2 status

# Check PM2 logs
pm2 logs --lines 50

# Exit session
exit
```

**Expected in PM2 status:**
```
┌─────┬──────────┬─────────────┬─────────┬─────────┐
│ id  │ name     │ mode        │ status  │ cpu     │
├─────┼──────────┼─────────────┼─────────┼─────────┤
│ 0   │ bmi-api  │ cluster     │ online  │ 0%      │
│ 1   │ bmi-api  │ cluster     │ online  │ 0%      │
└─────┴──────────┴─────────────┴─────────┴─────────┘
```

---

### Step 8.5: Register Backend Instances with Target Group

Once both instances are deployed and running, register them with the backend target group.

**AWS Console:**
1. Navigate to **EC2** → **Target Groups**
2. Select `bmi-backend-tg`
3. Go to **Targets** tab
4. Click **Register targets**
5. Select both `bmi-backend-1` and `bmi-backend-2`
6. Click **Include as pending below**
7. Click **Register pending targets**
8. Wait ~2-3 minutes for health checks to pass

**AWS CLI:**

```powershell
# Get backend target group ARN
$backendTgArn = (aws elbv2 describe-target-groups --names bmi-backend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Get backend instance IDs
$backendInstance1 = (aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-1" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[0].Instances[0].InstanceId' --output text)
$backendInstance2 = (aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-2" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Register instances with target group
aws elbv2 register-targets `
    --target-group-arn $backendTgArn `
    --targets Id=$backendInstance1,Port=3000 Id=$backendInstance2,Port=3000 `
    --region ap-south-1

Write-Host "✅ Backend instances registered with target group" -ForegroundColor Green
Write-Host "⏱️  Waiting for health checks to pass (2-3 minutes)..." -ForegroundColor Yellow
```

### ✅ Verification Step 8.5

```powershell
# Check target health status
aws elbv2 describe-target-health --target-group-arn $backendTgArn --region ap-south-1 --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table
```

**Expected output (after 2-3 min):**
```
------------------------------------------------------------
|                DescribeTargetHealth                      |
+---------------------+---------+-------------------------+
| i-xxxxxxxxxxxxxxxxx | healthy | (blank)                 |
| i-yyyyyyyyyyyyyyyyy | healthy | (blank)                 |
+---------------------+---------+-------------------------+
```

**If status is "initial":** Wait 2-3 minutes for health checks to complete.

**If status is "unhealthy":** Check:
- PM2 is running (`pm2 status`)
- Health endpoint works (`curl localhost:3000/health`)
- Security groups allow port 3000
- Check deployment logs

---

### ✅ Phase 8 Complete Verification

```powershell
Write-Host "=== Phase 8 Backend Instances Verification ===" -ForegroundColor Green

# 1. Check instances are running
$backendInstances = aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-*" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name]' --output table
Write-Host "`nBackend Instances:"
Write-Host $backendInstances

# 2. Check target health
$targetHealth = aws elbv2 describe-target-health --target-group-arn $backendTgArn --region ap-south-1 --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
Write-Host "`nTarget Health:"
Write-Host $targetHealth

# 3. Test backend ALB health (internal - may not work from local machine)
Write-Host "`n✅ Backend instances deployed and registered!" -ForegroundColor Green
Write-Host "⚠️  Backend ALB is internal - can only be accessed from VPC" -ForegroundColor Yellow
```

**Success criteria:**
- ✅ 2 backend instances running in different AZs
- ✅ Both instances registered with `bmi-backend-tg`
- ✅ Target health status is **healthy** for both
- ✅ PM2 running in cluster mode (2 processes per instance)
- ✅ Database migrations completed successfully
- ✅ Backend API responding on port 3000

**If all checks pass, proceed to Phase 9.** ✅

---

## Phase 9: Frontend Auto Scaling Group (10 minutes)

### Overview
Create an Auto Scaling Group for frontend instances with CPU-based scaling policy (60% target). Instances will serve React app via nginx and proxy API requests to backend ALB.

### Step 9.1: Create Launch Template

**AWS Console Steps:**
1. Navigate to **EC2** → **Launch Templates**
2. Click **Create launch template**
3. **Launch template name and description:**
   - **Launch template name**: `bmi-frontend-lt`
   - **Template version description**: `Frontend launch template with nginx and React app`
4. **Application and OS Images (Amazon Machine Image):**
   - Click **My AMIs** tab
   - Select `bmi-frontend-golden-ami`
5. **Instance type**: `t3.micro`
6. **Key pair (login)**: Don't include in launch template
7. **Network settings:**
   - **Subnet**: **Don't include in launch template** ⚠️ (ASG will specify this)
   - **Firewall (security groups)**: Select existing → `frontend-ec2-sg`
8. **Advanced details:**
   - **IAM instance profile**: Select `EC2RoleForBMIApp`
   - **Metadata version**: `V2 only (token required)` (recommended)
   - **Metadata response hop limit**: `1`
   - **User data**:

```bash
#!/bin/bash
# Frontend deployment script
curl -o /tmp/deploy-frontend.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/deploy-frontend.sh
chmod +x /tmp/deploy-frontend.sh
/tmp/deploy-frontend.sh
```

9. Click **Create launch template**

**AWS CLI:**

```powershell
# Get frontend AMI ID
$frontendAmiId = (aws ec2 describe-images --owners self --filters "Name=name,Values=bmi-frontend-golden-ami" --region ap-south-1 --query 'Images[0].ImageId' --output text)

# Get frontend EC2 security group ID
$frontendEc2SgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=frontend-ec2-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Create launch template JSON
$launchTemplateData = @"
{
  "ImageId": "$frontendAmiId",
  "InstanceType": "t3.micro",
  "SecurityGroupIds": ["$frontendEc2SgId"],
  "IamInstanceProfile": {
    "Name": "EC2RoleForBMIApp"
  },
  "MetadataOptions": {
    "HttpTokens": "required",
    "HttpPutResponseHopLimit": 1
  },
  "UserData": "$(([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('#!/bin/bash
curl -o /tmp/deploy-frontend.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/deploy-frontend.sh
chmod +x /tmp/deploy-frontend.sh
/tmp/deploy-frontend.sh'))))"
}
"@

# Save to file
$launchTemplateData | Out-File -FilePath launch-template.json -Encoding utf8

# Create launch template
aws ec2 create-launch-template `
    --launch-template-name bmi-frontend-lt `
    --version-description "Frontend launch template with nginx and React" `
    --launch-template-data file://launch-template.json `
    --region ap-south-1
```

### ✅ Verification Step 9.1

```powershell
# Verify launch template
aws ec2 describe-launch-templates --launch-template-names bmi-frontend-lt --region ap-south-1 --query 'LaunchTemplates[0].[LaunchTemplateName,LaunchTemplateId,LatestVersionNumber]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|              DescribeLaunchTemplates                     |
+-------------------+----------------------+---------------+
| bmi-frontend-lt   | lt-xxxxxxxxxxxxxxxxx | 1             |
+-------------------+----------------------+---------------+
```

---

### Step 9.2: Create Auto Scaling Group

**AWS Console Steps:**
1. Navigate to **EC2** → **Auto Scaling Groups**
2. Click **Create Auto Scaling group**

**Step 1: Choose launch template**
- **Auto Scaling group name**: `bmi-frontend-asg`
- **Launch template**: Select `bmi-frontend-lt`
- **Version**: `Latest`
- Click **Next**

**Step 2: Choose instance launch options**
- **VPC**: `devops-vpc`
- **Availability Zones and subnets**: Select **both private subnets**:
  - `devops-subnet-private1-ap-south-1a` ⚠️
  - `devops-subnet-private2-ap-south-1b` ⚠️
- Click **Next**

**Step 3: Configure advanced options**
- **Load balancing**: `Attach to an existing load balancer`
- **Choose from your load balancer target groups**: Select `bmi-frontend-tg`
- **Health checks**:
  - **Health check type**: Enable `ELB` health check ✅
  - **Health check grace period**: `300` seconds (5 minutes)
  - **Enable group metrics collection within CloudWatch**: ✅ (optional but recommended)
- Click **Next**

**Step 4: Configure group size and scaling policies**
- **Group size:**
  - **Desired capacity**: `2`
  - **Minimum capacity**: `1`
  - **Maximum capacity**: `4`
- **Scaling policies**: `Target tracking scaling policy`
  - **Scaling policy name**: `cpu-target-tracking`
  - **Metric type**: `Average CPU utilization`
  - **Target value**: `60` ⚠️ (this is our scaling threshold!)
  - **Instances need**: `60` seconds warmup before including in metrics
- **Instance scale-in protection**: Leave disabled
- Click **Next**

**Step 5: Add notifications**
- Skip (or configure SNS if you want notifications)
- Click **Next**

**Step 6: Add tags**
- Click **Add tag**
- **Key**: `Name`
- **Value**: `bmi-frontend-asg-instance`
- **Tag new instances**: ✅
- Click **Next**

**Step 7: Review**
- Review all settings
- Click **Create Auto Scaling group**

**AWS CLI:**

```powershell
# Get frontend target group ARN
$frontendTgArn = (aws elbv2 describe-target-groups --names bmi-frontend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group `
    --auto-scaling-group-name bmi-frontend-asg `
    --launch-template LaunchTemplateName=bmi-frontend-lt,Version='$Latest' `
    --min-size 1 `
    --max-size 4 `
    --desired-capacity 2 `
    --default-cooldown 300 `
    --health-check-type ELB `
    --health-check-grace-period 300 `
    --vpc-zone-identifier "$privateSubnet1,$privateSubnet2" `
    --target-group-arns $frontendTgArn `
    --tags "Key=Name,Value=bmi-frontend-asg-instance,PropagateAtLaunch=true" `
    --region ap-south-1

Write-Host "✅ Auto Scaling Group created" -ForegroundColor Green

# Create target tracking scaling policy (CPU 60%)
aws autoscaling put-scaling-policy `
    --auto-scaling-group-name bmi-frontend-asg `
    --policy-name cpu-target-tracking `
    --policy-type TargetTrackingScaling `
    --target-tracking-configuration '{
      "PredefinedMetricSpecification": {
        "PredefinedMetricType": "ASGAverageCPUUtilization"
      },
      "TargetValue": 60.0
    }' `
    --region ap-south-1

Write-Host "✅ CPU-based scaling policy created (60% target)" -ForegroundColor Green
```

### ⏱️ Wait Time: 5-7 minutes

The ASG will launch 2 instances and each needs time to:
1. Boot up (~2 min)
2. Run deployment script (~5 min):
   - Clone repo
   - Build React app
   - Configure nginx
   - Start nginx

---

### ✅ Verification Step 9.2

```powershell
# Check ASG status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].[AutoScalingGroupName,MinSize,DesiredCapacity,MaxSize,Instances[*].[InstanceId,LifecycleState]]' --output json
```

**Expected output:**
```json
[
  "bmi-frontend-asg",
  1,
  2,
  4,
  [
    ["i-xxxxxxxxxxxxxxxxx", "InService"],
    ["i-yyyyyyyyyyyyyyyyy", "InService"]
  ]
]
```

---

### Step 9.3: Monitor Frontend Deployment

```powershell
# Get one of the frontend instance IDs
$frontendInstanceId = (aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

# Start SSM session
aws ssm start-session --target $frontendInstanceId --region ap-south-1
```

**Once connected, check logs:**

```bash
# Check frontend deployment log
sudo tail -f /var/log/frontend-deploy.log

# Or check cloud-init log
sudo tail -f /var/log/cloud-init-output.log

# Check nginx status
sudo systemctl status nginx

# Test health endpoint
curl localhost/health

# Test nginx serves the app
curl -I localhost

# Exit
exit
```

**Expected:**
- Deployment log shows successful React build
- Nginx is **active (running)**
- Health endpoint returns 200
- Homepage returns 200

---

### Step 9.4: Verify Frontend Target Group Health

```powershell
# Check frontend target health
$frontendTgArn = (aws elbv2 describe-target-groups --names bmi-frontend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 describe-target-health --target-group-arn $frontendTgArn --region ap-south-1 --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table
```

**Expected output (wait 5-7 min):**
```
------------------------------------------------------------
|                DescribeTargetHealth                      |
+---------------------+---------+-------------------------+
| i-xxxxxxxxxxxxxxxxx | healthy | (blank)                 |
| i-yyyyyyyyyyyyyyyyy | healthy | (blank)                 |
+---------------------+---------+-------------------------+
```

**If "initial" or "unhealthy":** Wait longer or check:
- Deployment script completed
- Nginx is running
- `/health` endpoint returns 200
- Security groups correct

---

### Step 9.5: Access the Application! 🎉

```powershell
# Get Frontend ALB DNS
$frontendAlbDns = (aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)

Write-Host "`n🎉 YOUR APPLICATION IS LIVE! 🎉" -ForegroundColor Green
Write-Host "`nApplication URL: http://$frontendAlbDns" -ForegroundColor Cyan
Write-Host "`nOpen this URL in your browser to access the BMI Health Tracker!" -ForegroundColor Yellow

# Open in default browser (Windows)
Start-Process "http://$frontendAlbDns"
```

**Test the application:**
1. Open the URL in your browser
2. You should see the **BMI Health Tracker** interface
3. Try adding a measurement:
   - Weight: 70 kg
   - Height: 175 cm
   - Age: 30
   - Sex: Male
   - Activity: Moderate
   - Date: Today
4. Click **Calculate**
5. Check recent measurements appear
6. Check 30-day trend chart displays

---

### ✅ Phase 9 Complete Verification

```powershell
Write-Host "=== Phase 9 Frontend Auto Scaling Verification ===" -ForegroundColor Green

# 1. ASG status
$asgStatus = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' --output text
Write-Host "`nASG Capacity (Min/Desired/Max): $asgStatus"

# 2. Running instances
$instances = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' --output table
Write-Host "`nFrontend Instances:"
Write-Host $instances

# 3. Target health
$targetHealth = aws elbv2 describe-target-health --target-group-arn $frontendTgArn --region ap-south-1 --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table
Write-Host "`nTarget Health:"
Write-Host $targetHealth

# 4. Scaling policy
$scalingPolicy = aws autoscaling describe-policies --auto-scaling-group-name bmi-frontend-asg --region ap-south-1 --query 'ScalingPolicies[0].PolicyName' --output text
Write-Host "`n✅ Scaling Policy: $scalingPolicy (CPU 60% target)" -ForegroundColor Green

# 5. Application URL
$appUrl = "http://$frontendAlbDns"
Write-Host "`n🎉 Application URL: $appUrl" -ForegroundColor Cyan

Write-Host "`n✅ Phase 9 Complete - Frontend Auto Scaling is LIVE!" -ForegroundColor Green
```

**Success criteria:**
- ✅ ASG created with min=1, desired=2, max=4
- ✅ 2 frontend instances running in different AZs
- ✅ Both instances InService and healthy
- ✅ Target tracking scaling policy active (CPU 60%)
- ✅ Frontend ALB is accessible from internet
- ✅ Application loads and functions correctly
- ✅ Can add measurements and see results

**If all checks pass, proceed to Phase 10 for load testing!** ✅

---

## Phase 10: Load Testing and Monitoring (15 minutes)

### Overview
Trigger auto-scaling by generating sustained CPU load on frontend instances. Monitor the scaling behavior in real-time.

### Step 10.1: Install Apache Bench (Load Testing Tool)

**On Windows (via WSL2 or Cygwin):**

If you have WSL2 installed:
```powershell
# Open WSL2
wsl

# Install Apache Bench in Linux subsystem
sudo apt-get update
sudo apt-get install -y apache2-utils

# Verify installation
ab -V
```

**Alternative: Use Cloud9 or EC2 instance in same region:**

```powershell
# Launch a temporary t3.micro instance in public subnet
# Connect via SSM and run:
sudo dnf install -y httpd-tools

# Verify
ab -V
```

---

### Step 10.2: Download Monitoring Scripts

```bash
# In your Linux environment (WSL2, Cloud9, or EC2)
# Download monitoring script
curl -o monitor.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/load-test/monitor.sh
chmod +x monitor.sh

# Download load test script
curl -o quick-test.sh https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-CPU/load-test/quick-test.sh
chmod +x quick-test.sh

# Verify scripts downloaded
ls -lh monitor.sh quick-test.sh
```

### ✅ Verification Step 10.2

```bash
# Check scripts are executable
test -x monitor.sh && echo "✅ monitor.sh is executable" || echo "❌ not executable"
test -x quick-test.sh && echo "✅ quick-test.sh is executable" || echo "❌ not executable"
```

---

### Step 10.3: Start Real-Time Monitoring

Open a **second terminal/tab** and start monitoring:

```bash
# Run monitoring script (replace with your frontend ALB DNS)
./monitor.sh bmi-frontend-asg ap-south-1
```

**The monitor will show:**
- Current ASG capacity (Min/Desired/Max/Current)
- Instance list with state, health, AZ, and CPU %
- Recent scaling activities
- Auto-refreshes every 10 seconds

**Expected initial output:**
```
=========================================
Auto Scaling Group Status
=========================================
Time: 2026-01-28 14:30:00

Capacity:
  Min: 1 | Desired: 2 | Max: 4 | Current: 2

Instances:
┌────────────────────┬──────────┬─────────┬──────────────┬────────┐
│ Instance ID        │ State    │ Health  │ Zone         │ CPU %  │
├────────────────────┼──────────┼─────────┼──────────────┼────────┤
│ i-xxxxxxxxxxxxxxxxx│ InService│ Healthy │ ap-south-1a  │ 5.2%   │
│ i-yyyyyyyyyyyyyyyyy│ InService│ Healthy │ ap-south-1b  │ 4.8%   │
└────────────────────┴──────────┴─────────┴──────────────┴────────┘

Recent Scaling Activities (Last 5):
Launching instance i-xxxxxxxxxxxxxxxxx | Successful | 7 minutes ago
Launching instance i-yyyyyyyyyyyyyyyyy | Successful | 7 minutes ago
```

**Keep this terminal open during load testing!**

---

### Step 10.4: Run Load Test

In your **first terminal**, run the load test:

```bash
# Get your frontend ALB DNS from PowerShell
# Then run in Linux environment:

./quick-test.sh http://<your-frontend-alb-dns>.ap-south-1.elb.amazonaws.com
```

**Example:**
```bash
./quick-test.sh http://bmi-frontend-alb-123456789.ap-south-1.elb.amazonaws.com
```

**The test will run through 5 phases:**

1. **Phase 1: Warmup (30 seconds)**
   - 1,000 requests, 10 concurrent users
   - Warms up the instances

2. **Phase 2: Gradual Increase (60 seconds)**
   - 5,000 requests, 25 concurrent users
   - CPU starts climbing

3. **Phase 3: Heavy Load - GET Requests (5 minutes)**
   - 25,000 requests, 100 concurrent users
   - Sustained load on homepage

4. **Phase 4: Heavy Load - POST Requests (concurrent)**
   - Posts BMI calculations
   - CPU-intensive operations

5. **Phase 5: Heavy Load - API GET (concurrent)**
   - Fetches measurements
   - Database queries

**Expected output:**
```
=========================================
BMI App Auto-Scaling Load Test
=========================================

Target: http://bmi-frontend-alb-xxxxx.ap-south-1.elb.amazonaws.com
Concurrent Users: 100
Total Requests: 50000
Duration: 300 seconds

✓ Connection successful

=========================================
Starting Load Test
=========================================

Phase 1: Warmup (30 seconds)
Phase 2: Gradual Increase (60 seconds)
Phase 3: Heavy Load - GET Requests
Target: http://...
Phase 4: Heavy Load - POST Requests
Phase 5: Heavy Load - API GET Requests

Load test complete!
Check monitor for scaling activity
```

### ⏱️ Expected Timeline:

**0-2 minutes:** Initial warmup, CPU starts climbing (20-40%)
**2-4 minutes:** CPU hits 60%+, CloudWatch alarm triggers
**4-6 minutes:** ASG launches new instance(s), deployment begins
**6-8 minutes:** New instances become healthy, join target group
**8-10 minutes:** Load distributes across 3-4 instances, CPU stabilizes
**After test ends:** 5-10 minutes cooldown, ASG scales back down to 2

---

### Step 10.5: Monitor in AWS Console

While load test is running, open these AWS Console tabs:

**Tab 1: Auto Scaling Group Activity**
1. Navigate to **EC2** → **Auto Scaling Groups**
2. Select `bmi-frontend-asg`
3. Go to **Activity** tab
4. Click refresh every 30 seconds
5. Watch for "Launching a new EC2 instance" messages

**Tab 2: CloudWatch Metrics**
1. Navigate to **CloudWatch** → **Metrics** → **All metrics**
2. Select **EC2** → **By Auto Scaling Group**
3. Select `bmi-frontend-asg` → `CPUUtilization`
4. Change time range to "Last 1 hour"
5. Set refresh to "1 minute"
6. Watch CPU climb above 60% threshold

**Tab 3: Target Group Health**
1. Navigate to **EC2** → **Target Groups**
2. Select `bmi-frontend-tg`
3. Go to **Targets** tab
4. Watch new instances appear and become healthy

**Tab 4: CloudWatch Alarms**
1. Navigate to **CloudWatch** → **Alarms**
2. Find the alarm created by target tracking policy
3. Watch it transition from OK → ALARM → OK

---

### ✅ Verification Step 10.5

**During load test, verify these behaviors:**

```powershell
# In PowerShell (Windows), check ASG desired capacity changes
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' --output text

# Should show increase during load (e.g., 1 2 4 → 1 3 4 → 1 4 4)
```

```bash
# In monitoring terminal, watch for these events:
# - CPU increases above 60%
# - "Launching instance" activity
# - New instances appear in list
# - CPU redistributes and drops
```

**Success indicators:**
- ✅ CPU climbs above 60% within 2-4 minutes
- ✅ ASG desired capacity increases (2 → 3 or 4)
- ✅ New instances launch within 1-2 minutes of threshold breach
- ✅ New instances deploy and become healthy (5-7 minutes)
- ✅ CPU load distributes across all instances
- ✅ Overall CPU drops back below 60% after scaling

---

### Step 10.6: Post-Test Verification

After load test completes, monitor scale-in behavior:

```bash
# Continue watching monitor.sh output
# Wait 5-10 minutes after test ends

# Expected behavior:
# - CPU drops below 60% on all instances
# - After cooldown period (5-7 min), ASG scales in
# - Desired capacity returns to 2
# - Extra instances terminate
```

**Check scaling activities:**
```powershell
# View recent scaling activities
aws autoscaling describe-scaling-activities --auto-scaling-group-name bmi-frontend-asg --max-records 10 --region ap-south-1 --query 'Activities[*].[StartTime,StatusCode,Description]' --output table
```

**Expected output:**
```
------------------------------------------------------------
|              DescribeScalingActivities                   |
+------------------+-------------+-------------------------+
| 2026-01-28T14:45 | Successful  | Terminating instance... |
| 2026-01-28T14:35 | Successful  | Launching instance...   |
| 2026-01-28T14:25 | Successful  | Launching instance...   |
+------------------+-------------+-------------------------+
```

---

### ✅ Phase 10 Complete Verification

Run final verification checks:

```powershell
Write-Host "=== Phase 10 Load Testing Verification ===" -ForegroundColor Green

# 1. Check ASG returned to desired capacity of 2
$currentCapacity = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].[DesiredCapacity,length(Instances)]' --output text
Write-Host "`nCurrent Capacity (Desired/Actual): $currentCapacity"

# 2. Check scaling activities occurred
$scalingCount = aws autoscaling describe-scaling-activities --auto-scaling-group-name bmi-frontend-asg --max-records 20 --region ap-south-1 --query 'length(Activities)' --output text
Write-Host "Total Scaling Activities: $scalingCount"

# 3. Verify app still works
Write-Host "`nTesting application accessibility..."
$frontendAlbDns = (aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
$response = curl -s -o /dev/null -w "%{http_code}" "http://$frontendAlbDns"
if ($response -eq "200") {
    Write-Host "✅ Application is accessible (HTTP 200)" -ForegroundColor Green
} else {
    Write-Host "⚠️  Application returned HTTP $response" -ForegroundColor Yellow
}

Write-Host "`n✅ Phase 10 Complete - Auto-scaling tested successfully!" -ForegroundColor Green
```

**Success criteria:**
- ✅ ASG scaled out during load (2 → 3 or 4 instances)
- ✅ New instances deployed and became healthy
- ✅ CPU load distributed across instances
- ✅ ASG scaled back in after load ended (→ 2 instances)
- ✅ Application remained accessible throughout
- ✅ No service disruption during scaling events

**If all checks pass, proceed to Phase 11.** ✅

---

## Phase 11: Final Verification and Testing (5 minutes)

### Overview
Comprehensive verification that the entire system is working correctly.

### Step 11.1: Architecture Verification

```powershell
Write-Host "=== Complete Architecture Verification ===" -ForegroundColor Green

# 1. VPC and Network
Write-Host "`n1. Network Infrastructure:" -ForegroundColor Cyan
$vpcId = (aws ec2 describe-vpcs --filters "Name=tag:Name,Values=devops-vpc" --region ap-south-1 --query 'Vpcs[0].VpcId' --output text)
Write-Host "   ✅ VPC: $vpcId"

$endpoints = aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpcId" "Name=tag:Name,Values=bmi-*" --region ap-south-1 --query 'VpcEndpoints[*].VpcEndpointId' --output text
$endpointCount = ($endpoints -split '\s+').Count
Write-Host "   ✅ VPC Endpoints: $endpointCount SSM endpoints"

# 2. Database
Write-Host "`n2. Database Layer:" -ForegroundColor Cyan
$dbStatus = aws rds describe-db-clusters --db-cluster-identifier bmi-aurora-cluster --region ap-south-1 --query 'DBClusters[0].[Status,Endpoint]' --output text
Write-Host "   ✅ Aurora Cluster: $dbStatus"

# 3. Backend
Write-Host "`n3. Backend Layer:" -ForegroundColor Cyan
$backendInstances = aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-*" "Name=instance-state-name,Values=running" --region ap-south-1 --query 'Reservations[*].Instances[*].InstanceId' --output text
$backendCount = ($backendInstances -split '\s+').Count
Write-Host "   ✅ Backend EC2 Instances: $backendCount running"

$backendAlb = aws elbv2 describe-load-balancers --names bmi-backend-alb --region ap-south-1 --query 'LoadBalancers[0].[State.Code,Scheme]' --output text
Write-Host "   ✅ Backend ALB: $backendAlb"

$backendTgArn = (aws elbv2 describe-target-groups --names bmi-backend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)
$backendHealthy = aws elbv2 describe-target-health --target-group-arn $backendTgArn --region ap-south-1 --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text
Write-Host "   ✅ Backend Healthy Targets: $backendHealthy/$backendCount"

# 4. Frontend
Write-Host "`n4. Frontend Layer:" -ForegroundColor Cyan
$asgStats = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,length(Instances)]' --output text
Write-Host "   ✅ Frontend ASG (Min/Desired/Max/Current): $asgStats"

$frontendAlb = aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].[State.Code,Scheme]' --output text
Write-Host "   ✅ Frontend ALB: $frontendAlb"

$frontendTgArn = (aws elbv2 describe-target-groups --names bmi-frontend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)
$frontendHealthy = aws elbv2 describe-target-health --target-group-arn $frontendTgArn --region ap-south-1 --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text
$frontendTotal = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].length(Instances)' --output text
Write-Host "   ✅ Frontend Healthy Targets: $frontendHealthy/$frontendTotal"

# 5. Scaling Policy
Write-Host "`n5. Auto-Scaling Configuration:" -ForegroundColor Cyan
$scalingPolicy = aws autoscaling describe-policies --auto-scaling-group-name bmi-frontend-asg --region ap-south-1 --query 'ScalingPolicies[0].[PolicyName,PolicyType,TargetTrackingConfiguration.TargetValue]' --output text
Write-Host "   ✅ Scaling Policy: $scalingPolicy"

# 6. Application URL
Write-Host "`n6. Application Access:" -ForegroundColor Cyan
$appUrl = (aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
Write-Host "   ✅ Application URL: http://$appUrl"

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "✅ All Components Verified!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
```

---

### Step 11.2: Functional Testing Checklist

Open your application and verify these features work:

**Application URL:**
```powershell
$appUrl = (aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
Write-Host "Open in browser: http://$appUrl" -ForegroundColor Cyan
Start-Process "http://$appUrl"
```

**Manual Testing Checklist:**
- [ ] Application loads without errors
- [ ] UI displays correctly (no broken styles/images)
- [ ] Can enter weight, height, age, sex, activity level, date
- [ ] "Calculate" button works
- [ ] Results display: BMI, BMI category, BMR, daily calories
- [ ] New measurement appears in "Recent Measurements" section
- [ ] 30-day trend chart displays and updates
- [ ] Can add multiple measurements
- [ ] Chart shows multiple data points correctly
- [ ] Backend API is responding (check browser Network tab)
- [ ] No console errors in browser developer tools

---

### Step 11.3: Performance Testing

Test application performance under normal load:

```bash
# Run a smaller load test (normal traffic simulation)
ab -n 1000 -c 10 http://<frontend-alb-dns>/

# Expected results:
# - Requests per second: > 100
# - Mean time per request: < 100ms
# - Failed requests: 0
```

---

### Step 11.4: High Availability Testing (Optional)

Test that the application survives instance failure:

```powershell
# Terminate one frontend instance
$instanceToTerminate = (aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

Write-Host "Terminating instance: $instanceToTerminate" -ForegroundColor Yellow
aws ec2 terminate-instances --instance-ids $instanceToTerminate --region ap-south-1

Write-Host "ASG will automatically replace this instance within 5 minutes" -ForegroundColor Yellow
Write-Host "Application should remain accessible during replacement" -ForegroundColor Green

# Monitor ASG activity
aws autoscaling describe-scaling-activities --auto-scaling-group-name bmi-frontend-asg --max-records 5 --region ap-south-1 --query 'Activities[*].[StartTime,Description,StatusCode]' --output table
```

**Expected behavior:**
- Application remains accessible
- ASG detects unhealthy/missing instance
- Launches replacement instance
- Replacement becomes healthy
- Desired capacity maintained

---

### ✅ Phase 11 Complete Verification Checklist

Run through this final checklist:

```
INFRASTRUCTURE:
✅ VPC with 4 subnets (2 public, 2 private) in 2 AZs
✅ NAT Gateway for private subnet internet access
✅ 3 VPC endpoints for SSM access
✅ 6 security groups configured correctly

DATABASE:
✅ Aurora Serverless v2 cluster running (0.5-2 ACU)
✅ Database accessible from backend instances
✅ Migrations completed successfully
✅ Connection pooling working

IAM & SECURITY:
✅ EC2 IAM role with SSM + Parameter Store access
✅ 5 parameters in Parameter Store (all encrypted)
✅ No SSH keys required (SSM Session Manager)
✅ All instances in private subnets

BACKEND:
✅ 2 backend EC2 instances in different AZs
✅ PM2 running in cluster mode (2 processes/instance)
✅ Node.js 20.x on Amazon Linux 2023
✅ Connected to Aurora successfully
✅ Internal ALB healthy and routing traffic

FRONTEND:
✅ Auto Scaling Group (min=1, desired=2, max=4)
✅ Launch template with Golden AMI
✅ Target tracking policy (CPU 60%)
✅ nginx serving React app
✅ Proxy to backend ALB configured
✅ Public ALB healthy and accessible

AUTO-SCALING:
✅ Scales out when CPU > 60% (verified in Phase 10)
✅ Scales in after cooldown period
✅ Health checks working correctly
✅ No downtime during scaling events

APPLICATION:
✅ Frontend loads correctly
✅ Can add measurements
✅ Backend API responds
✅ Database queries work
✅ Chart displays trends
✅ No errors in console

MONITORING:
✅ CloudWatch metrics collecting
✅ Target tracking alarm created automatically
✅ ASG activities logged
✅ Can monitor via AWS CLI/Console
```

**If ALL items are checked, congratulations! 🎉**

---

## Cost Management

### Current Running Costs (Hourly)

```
Aurora Serverless v2 (0.5 ACU):    ~$0.06/hour
NAT Gateway:                       ~$0.045/hour
2 Backend t3.micro instances:      ~$0.021/hour
2-4 Frontend t3.micro instances:   ~$0.021-0.042/hour
ALB (2x):                          ~$0.050/hour
VPC Endpoints (3x):                ~$0.03/hour
-------------------------------------------------
TOTAL:                             ~$0.227-0.248/hour
                                   ~$5.45-5.95/day
```

### Cost Optimization Tips

**For Demo (1-2 hours):**
- ✅ Current setup is optimized
- ✅ Use t3.micro instances
- ✅ Aurora at minimum 0.5 ACU
- ❌ Don't enable Enhanced Monitoring

**For Extended Testing (24 hours):**
- Consider t3.nano for frontend (if sufficient)
- Reduce Aurora max ACU to 1
- Set ASG max to 3 instead of 4

**After Demo - DELETE EVERYTHING:**
- See [TEARDOWN-CHECKLIST.md](TEARDOWN-CHECKLIST.md)
- Most expensive: Aurora cluster (even when paused)
- NAT Gateway charges even when unused

---

## Troubleshooting Guide

### Issue 1: Frontend Not Loading

**Symptoms:** Frontend ALB returns 503 or Connection Refused

**Checks:**
```powershell
# 1. Check target health
$frontendTgArn = (aws elbv2 describe-target-groups --names bmi-frontend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $frontendTgArn --region ap-south-1 --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table

# 2. Check ASG instances
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names bmi-frontend-asg --region ap-south-1 --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' --output table
```

**Solutions:**

a) **If targets are "initial":** Wait 5-7 minutes for deployment
b) **If targets are "unhealthy":** Connect via SSM and check:
```bash
# Check deployment log
sudo tail -100 /var/log/frontend-deploy.log

# Check nginx status
sudo systemctl status nginx

# Check nginx error log
sudo tail -50 /var/log/nginx/error.log

# Test health endpoint locally
curl localhost/health

# Restart nginx if needed
sudo systemctl restart nginx
```

c) **If "Instance registration is still in progress":** Wait for health check grace period (5 minutes)

---

### Issue 2: Backend API Not Responding

**Symptoms:** Frontend loads but no data, API errors in browser console

**Checks:**
```powershell
# 1. Check backend target health
$backendTgArn = (aws elbv2 describe-target-groups --names bmi-backend-tg --region ap-south-1 --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $backendTgArn --region ap-south-1 --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' --output table

# 2. Check Parameter Store has correct backend URL
aws ssm get-parameter --name "/bmi-app/backend-alb-url" --region ap-south-1 --query 'Parameter.Value' --output text
```

**Solutions:**

a) **If backend URL is wrong in Parameter Store:**
```powershell
# Update with correct backend ALB DNS
$backendAlbDns = (aws elbv2 describe-load-balancers --names bmi-backend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
aws ssm put-parameter --name "/bmi-app/backend-alb-url" --value "http://$backendAlbDns" --type String --overwrite --region ap-south-1

# Restart frontend instances to pick up new value
# (or wait for new instances to launch)
```

b) **If backend instances are unhealthy:** Connect via SSM:
```bash
# Check PM2 status
pm2 status

# Check PM2 logs
pm2 logs --lines 100

# Check backend deployment log
sudo tail -100 /var/log/backend-deploy.log

# Restart PM2 if needed
pm2 restart all
```

c) **If database connection fails:**
```bash
# Check database connectivity
PGPASSWORD=$(aws ssm get-parameter --name "/bmi-app/db-password" --with-decryption --region ap-south-1 --query 'Parameter.Value' --output text)
DB_HOST=$(aws ssm get-parameter --name "/bmi-app/db-host" --region ap-south-1 --query 'Parameter.Value' --output text)
psql -h $DB_HOST -U postgres -d bmidb -c "SELECT 1"
```

---

### Issue 3: Auto-Scaling Not Triggering

**Symptoms:** Load test runs but ASG doesn't scale out

**Checks:**
```powershell
# 1. Check scaling policy exists
aws autoscaling describe-policies --auto-scaling-group-name bmi-frontend-asg --region ap-south-1 --query 'ScalingPolicies[*].[PolicyName,PolicyType,TargetTrackingConfiguration.TargetValue]' --output table

# 2. Check CloudWatch alarm
aws cloudwatch describe-alarms --alarm-name-prefix TargetTracking-bmi-frontend-asg --region ap-south-1 --query 'MetricAlarms[*].[AlarmName,StateValue,Threshold]' --output table

# 3. Check recent CPU metrics
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=AutoScalingGroupName,Value=bmi-frontend-asg --start-time $(Get-Date).AddMinutes(-15).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") --end-time $(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") --period 60 --statistics Average --region ap-south-1
```

**Solutions:**

a) **CPU not high enough:** Increase load test concurrency
```bash
# Run more aggressive load test
ab -n 100000 -c 200 -t 300 http://<frontend-alb-dns>/
```

b) **Warmup period not over:** Wait 60 seconds after instances launch

c) **Reached max capacity:** Check if already at max (4 instances)

d) **Recreate scaling policy:**
```powershell
# Delete existing policy
aws autoscaling delete-policy --auto-scaling-group-name bmi-frontend-asg --policy-name cpu-target-tracking --region ap-south-1

# Recreate with correct settings
aws autoscaling put-scaling-policy `
    --auto-scaling-group-name bmi-frontend-asg `
    --policy-name cpu-target-tracking `
    --policy-type TargetTrackingScaling `
    --target-tracking-configuration '{
      "PredefinedMetricSpecification": {
        "PredefinedMetricType": "ASGAverageCPUUtilization"
      },
      "TargetValue": 60.0
    }' `
    --region ap-south-1
```

---

### Issue 4: SSM Session Manager Not Working

**Symptoms:** Can't connect to instances via Session Manager

**Checks:**
```powershell
# 1. Check VPC endpoints are available
aws ec2 describe-vpc-endpoints --filters "Name=tag:Name,Values=bmi-*" --region ap-south-1 --query 'VpcEndpoints[*].[Tags[?Key==`Name`].Value|[0],State]' --output table

# 2. Check IAM role attached to instance
aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-1" --region ap-south-1 --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text

# 3. Check SSM agent status (from CloudWatch if accessible)
aws ssm describe-instance-information --filters "Key=tag:Name,Values=bmi-backend-1" --region ap-south-1 --query 'InstanceInformationList[*].[InstanceId,PingStatus]' --output table
```

**Solutions:**

a) **VPC endpoints not available:** Wait 2-3 minutes or recreate them

b) **IAM role missing:** 
```powershell
# Associate IAM role with instance
$instanceId = (aws ec2 describe-instances --filters "Name=tag:Name,Values=bmi-backend-1" --region ap-south-1 --query 'Reservations[0].Instances[0].InstanceId' --output text)
aws ec2 associate-iam-instance-profile --instance-id $instanceId --iam-instance-profile Name=EC2RoleForBMIApp --region ap-south-1
```

c) **SSM agent not started:** Reboot instance
```powershell
aws ec2 reboot-instances --instance-ids $instanceId --region ap-south-1
```

---

### Issue 5: Database Connection Errors

**Symptoms:** Backend logs show "Connection refused" or "timeout" to Aurora

**Checks:**
```bash
# From backend instance via SSM
# Check Parameter Store values
aws ssm get-parameter --name "/bmi-app/db-host" --region ap-south-1 --query 'Parameter.Value' --output text
aws ssm get-parameter --name "/bmi-app/db-password" --with-decryption --region ap-south-1 --query 'Parameter.Value' --output text

# Test connectivity
nc -zv <db-host> 5432

# Try connecting with psql
PGPASSWORD=<password> psql -h <db-host> -U postgres -d bmidb -c "SELECT 1"
```

**Solutions:**

a) **Aurora not running:**
```powershell
aws rds describe-db-clusters --db-cluster-identifier bmi-aurora-cluster --region ap-south-1 --query 'DBClusters[0].Status' --output text
# If not "available", wait for it to start
```

b) **Security group incorrect:**
```powershell
# Check Aurora security group allows backend EC2 SG
$auroraSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=aurora-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)
$backendEc2SgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=backend-ec2-sg" --region ap-south-1 --query 'SecurityGroups[0].GroupId' --output text)

# Add rule if missing
aws ec2 authorize-security-group-ingress --group-id $auroraSgId --protocol tcp --port 5432 --source-group $backendEc2SgId --region ap-south-1
```

c) **Wrong endpoint:** Ensure using Writer endpoint, not Reader

---

### Issue 6: Amazon Linux 2023 Package Issues

**Symptoms:** `dnf` commands fail, packages not found

**Solutions:**

a) **Update package cache:**
```bash
sudo dnf clean all
sudo dnf makecache
```

b) **Enable correct repositories:**
```bash
# Check enabled repos
sudo dnf repolist

# Node.js 20 from official repo
sudo dnf install -y nodejs

# If nodejs not found, use NodeSource:
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs
```

c) **PostgreSQL 15 client:**
```bash
# Amazon Linux 2023 has postgresql15 package
sudo dnf install -y postgresql15

# Verify
psql --version
```

---

### Common Error Messages and Fixes

| Error | Cause | Solution |
|-------|-------|----------|
| `503 Service Unavailable` | No healthy targets | Wait for instances to deploy or check target health |
| `Target registration is still in progress` | Health check grace period | Wait 5 minutes |
| `Unable to connect to AWS Systems Manager` | VPC endpoints missing or IAM role issue | Check VPC endpoints are available, verify IAM role |
| `ECONNREFUSED` in PM2 logs | Database not accessible | Check Aurora status, security groups |
| `Migration failed: relation already exists` | Migration re-run | Safe to ignore if using `IF NOT EXISTS` |
| `npm ERR! code ELIFECYCLE` | Build failed | Check Node.js version (should be 20.x), check logs |
| `nginx: [emerg] bind() to 0.0.0.0:80 failed` | Port already in use | Check if nginx already running: `sudo systemctl status nginx` |
| `Health check failed` | App not responding on health endpoint | Check nginx config, verify `/health` endpoint |
| `UnauthorizedOperation` | IAM permissions missing | Check AWS CLI credentials have correct permissions |

---

## Summary

### What You've Built

**A production-ready, highly available, auto-scaling 3-tier web application:**

✅ **Network Layer:**
- VPC with public/private subnets across 2 AZs
- NAT Gateway for private subnet internet access
- VPC Endpoints for secure SSM access
- 6 security groups with least-privilege access

✅ **Database Layer:**
- Aurora Serverless v2 PostgreSQL (auto-scales compute)
- Multi-AZ for high availability
- Automated migrations
- Connection pooling via PM2

✅ **Backend Layer:**
- 2 fixed EC2 instances (manual, no auto-scaling)
- Node.js 20 + Express API
- PM2 cluster mode (4 worker processes total)
- Internal ALB for load distribution
- Private subnets (no public IPs)

✅ **Frontend Layer:**
- Auto Scaling Group (1-4 instances)
- CPU-based scaling (60% threshold)
- React 18 + Vite + Chart.js
- Nginx reverse proxy
- Public ALB for internet access
- Health checks with automatic recovery

✅ **Security & Operations:**
- No SSH keys required (SSM Session Manager)
- Secrets in Parameter Store (encrypted)
- IAM roles for EC2 with least privilege
- Golden AMIs for fast, consistent deployments
- All instances in private subnets
- Amazon Linux 2023 (latest, dnf-based)

✅ **Monitoring & Scaling:**
- CloudWatch metrics and alarms
- Target tracking scaling policy
- Automatic scale-out and scale-in
- Real-time monitoring scripts
- Load testing verified

---

### Key Metrics

**Setup Time:** ~60-75 minutes (with verification steps)
**Auto-Scaling:** Responds in 5-7 minutes to load changes
**High Availability:** Survives instance failures automatically
**Cost:** ~$0.23/hour (~$5.50/day if left running)
**Region:** ap-south-1 (Mumbai)
**OS:** Amazon Linux 2023 (dnf package manager)

---

### Teardown

**⚠️ IMPORTANT: Delete all resources after demo to avoid charges!**

Follow [TEARDOWN-CHECKLIST.md](TEARDOWN-CHECKLIST.md) to delete:
1. Auto Scaling Group (deletes frontend instances)
2. Launch Template
3. Backend EC2 instances
4. Load Balancers (frontend + backend)
5. Target Groups
6. Aurora Cluster ⚠️ (most expensive!)
7. RDS Subnet Group
8. Security Groups
9. VPC Endpoints (SSM endpoints)
10. AMIs (Golden AMIs)
11. Parameter Store parameters

**Estimated teardown time:** 20-30 minutes

---

### Next Steps

1. **Experiment with different scaling thresholds** (40%, 80%)
2. **Try ALB Request Count scaling** (see AutoScaling-FrontEnd-ALB-request/)
3. **Add CloudWatch Dashboard** for unified monitoring
4. **Implement HTTPS** with ACM certificate
5. **Add RDS read replicas** for database scaling
6. **Set up CI/CD pipeline** with GitHub Actions
7. **Add caching layer** with ElastiCache
8. **Implement logging** with CloudWatch Logs Insights

---

## Support and Resources

**Documentation:**
- [AWS Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/)
- [Amazon Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

**GitHub Repository:**
- [3-tier-web-app-auto-scalling](https://github.com/sarowar-alam/3-tier-web-app-auto-scalling)

**Related Files:**
- [TEARDOWN-CHECKLIST.md](TEARDOWN-CHECKLIST.md) - Complete teardown guide
- [README-AUTO-SCALING.md](../README-AUTO-SCALING.md) - Overview and comparison
- [EXISTING-VPC-REFERENCE.md](../EXISTING-VPC-REFERENCE.md) - VPC details

---

## Congratulations! 🎉

You've successfully deployed a production-ready auto-scaling application on AWS with comprehensive verification at every step!

**Your application features:**
- ✅ Auto-scaling based on CPU utilization
- ✅ High availability across multiple AZs
- ✅ Secure architecture (private subnets, no SSH)
- ✅ Serverless database with auto-scaling
- ✅ Load balancing and health checks
- ✅ Automated deployments with Golden AMIs
- ✅ Real-time monitoring and alerting
- ✅ Amazon Linux 2023 compatible

**Application URL:**
```powershell
$appUrl = (aws elbv2 describe-load-balancers --names bmi-frontend-alb --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)
Write-Host "🎉 Your BMI Health Tracker: http://$appUrl" -ForegroundColor Green
```

**Remember to delete all resources after your demo!**

---

*Last updated: January 28, 2026*
*Region: ap-south-1 (Mumbai)*
*OS: Amazon Linux 2023*
*Version: 2.0 (with comprehensive verification steps)*

