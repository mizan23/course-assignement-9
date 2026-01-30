# Existing VPC Infrastructure Reference

This document describes your existing VPC infrastructure that will be used for the auto-scaling demos.

---

## ✅ What You Already Have

### VPC Configuration
- **VPC Name**: `devops-vpc`
- **CIDR Block**: `10.0.0.0/16`
- **Region**: `ap-south-1` (Mumbai)
- **Availability Zones**: `ap-south-1a`, `ap-south-1b`

### Subnets (4 total)

#### Public Subnets
1. **devops-subnet-public1-ap-south-1a**
   - CIDR: `10.0.0.0/20`
   - AZ: `ap-south-1a`
   - Use: Frontend ALB, Golden AMI creation

2. **devops-subnet-public2-ap-south-1b**
   - CIDR: `10.0.16.0/20`
   - AZ: `ap-south-1b`
   - Use: Frontend ALB (Multi-AZ)

#### Private Subnets
3. **devops-subnet-private1-ap-south-1a**
   - CIDR: `10.0.128.0/20`
   - AZ: `ap-south-1a`
   - Use: Frontend ASG, Backend EC2, Aurora RDS

4. **devops-subnet-private2-ap-south-1b**
   - CIDR: `10.0.144.0/20`
   - AZ: `ap-south-1b`
   - Use: Frontend ASG, Backend EC2, Aurora RDS (Multi-AZ)

### Route Tables (5 total)

1. **devops-rtb-public**
   - Associations: 2 public subnets
   - Routes: Local + Internet Gateway

2. **devops-rtb-private1-ap-south-1a**
   - Association: devops-subnet-private1-ap-south-1a
   - Routes: Local + NAT Gateway + S3 Endpoint

3. **devops-rtb-private2-ap-south-1b**
   - Association: devops-subnet-private2-ap-south-1b
   - Routes: Local + NAT Gateway + S3 Endpoint

4. **rtb-00526e14e9fe58885** (default)
   - No custom associations

5. **rtb-032439a58f40084d8** (custom)
   - No current associations

### Network Connections

1. **devops-igw** (Internet Gateway)
   - ✅ Attached to VPC
   - ✅ Routes internet traffic to 2 public subnets

2. **devops-regional-nat** (NAT Gateway)
   - ✅ Located in public subnet
   - ✅ Provides internet access for 2 private subnets
   - ✅ 1 Elastic IP attached

3. **devops-vpce-s3** (S3 Gateway Endpoint)
   - ✅ Free tier eligible
   - ✅ Allows private S3 access without NAT charges

---

## ⚠️ What You Need to Create

### For Auto-Scaling Demo:

1. **VPC Endpoints for SSM** (Phase 1)
   - `bmi-ssm-endpoint` (com.amazonaws.ap-south-1.ssm)
   - `bmi-ec2messages-endpoint` (com.amazonaws.ap-south-1.ec2messages)
   - `bmi-ssmmessages-endpoint` (com.amazonaws.ap-south-1.ssmmessages)
   - **Cost**: ~$0.01/hour per endpoint (~$0.03/hour total)

2. **Security Groups** (Phase 5)
   - `ssm-endpoint-sg` (for VPC endpoints)
   - `frontend-alb-sg` (for public ALB)
   - `frontend-ec2-sg` (for frontend instances)
   - `backend-alb-sg` (for internal ALB)
   - `backend-ec2-sg` (for backend instances)
   - `aurora-sg` (for RDS database)

3. **Aurora Serverless v2** (Phase 2)
   - DB Subnet Group using your private subnets
   - Aurora PostgreSQL cluster

4. **Application Load Balancers** (Phase 7)
   - Frontend ALB (public subnets)
   - Backend ALB (private subnets)

5. **Auto Scaling Group** (Phase 9)
   - Frontend ASG in private subnets

6. **Backend EC2 Instances** (Phase 8)
   - 2 instances in private subnets (manual, no ASG)

---

## 💰 Cost Savings

By using your existing VPC infrastructure:

**What you DON'T pay for:**
- ✅ VPC creation (free anyway)
- ✅ NAT Gateway creation ($0.045/hour saved - already exists)
- ✅ Elastic IP ($0.005/hour saved - already attached)
- ✅ S3 Gateway Endpoint (free - already exists)
- ✅ Internet Gateway (free - already exists)

**What you WILL pay for:**
- SSM VPC Endpoints: ~$0.03/hour
- Aurora Serverless v2: ~$0.24-1.92/hour (depending on load)
- EC2 instances: ~$0.01/hour each (t3.micro)
- ALBs: ~$0.025/hour each
- Data transfer: Minimal for demo

**Total estimated cost**: ~$2-3 for 1-hour demo

---

## 📋 Infrastructure Mapping

### How the Demo Uses Your VPC:

```
devops-vpc (10.0.0.0/16)
│
├── Public Subnets (Internet-facing)
│   ├── devops-subnet-public1-ap-south-1a (10.0.0.0/20)
│   │   ├── Frontend ALB (bmi-frontend-alb)
│   │   └── Temporary Golden AMI instances
│   └── devops-subnet-public2-ap-south-1b (10.0.16.0/20)
│       └── Frontend ALB (Multi-AZ)
│
├── Private Subnets (No direct internet)
│   ├── devops-subnet-private1-ap-south-1a (10.0.128.0/20)
│   │   ├── Frontend ASG instances (2-4)
│   │   ├── Backend EC2 (bmi-backend-1)
│   │   ├── Backend ALB (bmi-backend-alb)
│   │   ├── Aurora RDS (Primary)
│   │   └── SSM VPC Endpoints
│   └── devops-subnet-private2-ap-south-1b (10.0.144.0/20)
│       ├── Frontend ASG instances (2-4)
│       ├── Backend EC2 (bmi-backend-2)
│       ├── Backend ALB (Multi-AZ)
│       ├── Aurora RDS (Replica)
│       └── SSM VPC Endpoints
│
├── Internet Gateway: devops-igw
├── NAT Gateway: devops-regional-nat
└── S3 Endpoint: devops-vpce-s3
```

---

## 🔒 Security Configuration

### Current Setup:
- ✅ Public subnets have IGW routes
- ✅ Private subnets have NAT Gateway routes
- ✅ S3 endpoint for cost-optimized S3 access
- ✅ Multi-AZ for high availability

### Additional Security (You'll Create):
- Security groups for each tier
- SSM VPC endpoints (no SSH keys needed)
- Private instances (no public IPs)
- Internal ALB for backend (not internet-facing)

---

## 🚀 Quick Start Checklist

Before starting the demo:

- [x] VPC exists: `devops-vpc`
- [x] 2 public subnets in different AZs
- [x] 2 private subnets in different AZs
- [x] NAT Gateway operational
- [x] Internet Gateway attached
- [x] S3 endpoint configured
- [ ] Create SSM VPC endpoints (Phase 1)
- [ ] Create security groups (Phase 5)
- [ ] Create Aurora database (Phase 2)
- [ ] Create IAM role (Phase 3)
- [ ] Set up Parameter Store (Phase 4)

---

## 📝 Notes

1. **NAT Gateway**: You only have 1 NAT Gateway, which is fine for demos but means:
   - Private subnets in both AZs route through this single NAT
   - If NAT fails, private instances lose internet access
   - For production, consider 2 NAT Gateways (one per AZ)

2. **Route Tables**: You have separate route tables for each private subnet, which is good practice.

3. **Region**: All resources are in **ap-south-1** (Mumbai). Ensure you select this region in AWS Console.

4. **CIDR Planning**: Your CIDR blocks are well-structured:
   - Public: 10.0.0.0/20, 10.0.16.0/20 (32,768 IPs total)
   - Private: 10.0.128.0/20, 10.0.144.0/20 (32,768 IPs total)
   - Plenty of space for auto-scaling!

---

## 🧹 Cleanup Considerations

When tearing down the demo:

**DO NOT DELETE:**
- ❌ devops-vpc
- ❌ devops subnets
- ❌ devops-igw
- ❌ devops-regional-nat
- ❌ devops-vpce-s3
- ❌ devops route tables

**DO DELETE:**
- ✅ All resources created during demo (see TEARDOWN-CHECKLIST.md)
- ✅ SSM VPC endpoints (bmi-*)
- ✅ Security groups (bmi-*, frontend-*, backend-*, aurora-sg)
- ✅ Aurora database
- ✅ ALBs
- ✅ ASG and instances
- ✅ Launch templates
- ✅ Target groups

---

## 🎯 Ready to Start?

Your infrastructure is perfect for this demo! Follow the updated setup guides:

- [CPU-Based Scaling](AutoScaling-FrontEnd-CPU/QUICK-DEMO-SETUP.md)
- [ALB Request Count Scaling](AutoScaling-FrontEnd-ALB-request/QUICK-DEMO-SETUP.md)

Both guides are now updated to use your **devops-vpc** in **ap-south-1**.

---
## 🧑‍💻 Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)
---
