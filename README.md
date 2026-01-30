# AWS Auto-Scaling Demonstration Setups

This project contains **two complete AWS auto-scaling demonstration setups** for the BMI Health Tracker application, each using a different scaling strategy.

---

## 📁 Project Structure

```
3-tier-web-app-auto-scalling/
├── backend/                           # Node.js Express API
├── frontend/                          # React + Vite UI
├── database/                          # PostgreSQL setup scripts
├── AutoScaling-FrontEnd-CPU/         # Setup #1: CPU-based scaling
└── AutoScaling-FrontEnd-ALB-request/ # Setup #2: ALB request count scaling
```

---

## 🎯 Two Auto-Scaling Strategies

### **Setup 1: CPU-Based Auto-Scaling** 
📂 [AutoScaling-FrontEnd-CPU/](AutoScaling-FrontEnd-CPU/)

**Scaling Trigger:** Average CPU Utilization  
**Target Value:** 60% CPU  
**Best For:** Compute-intensive applications  

**When to use:**
- Applications with variable CPU workloads
- Batch processing or data transformation
- When CPU directly correlates with load

**Pros:**
- ✅ Universal metric (works for any app)
- ✅ Fast response to compute load
- ✅ Protects against CPU-intensive attacks

**Cons:**
- ❌ May not reflect actual user load
- ❌ Inefficient for lightweight web apps
- ❌ Can be slow to trigger on some workloads

---

### **Setup 2: ALB Request Count Scaling** 
📂 [AutoScaling-FrontEnd-ALB-request/](AutoScaling-FrontEnd-ALB-request/)

**Scaling Trigger:** ALB Request Count per Target  
**Target Value:** 1000 requests/minute per instance  
**Best For:** Traffic-heavy web applications  

**When to use:**
- Web applications with consistent request patterns
- API services with predictable response times
- When scaling should match user traffic directly

**Pros:**
- ✅ Direct correlation with user traffic
- ✅ More predictable scaling behavior
- ✅ Better for capacity planning
- ✅ Ideal for web applications

**Cons:**
- ❌ Doesn't account for request complexity
- ❌ May scale unnecessarily on simple requests
- ❌ Requires load balancer (can't use with direct EC2)

---

## 🏗️ Architecture

Both setups use the same 3-tier architecture in your existing **devops-vpc** (ap-south-1):

```
Internet
   ↓
[Public ALB] ← Frontend Load Balancer (devops public subnets)
   ↓
[Frontend ASG] ← 2-4 EC2 instances (AUTO-SCALES, devops private subnets)
   ↓
[Internal ALB] ← Backend Load Balancer (devops private subnets)
   ↓
[Backend EC2] ← 2 fixed instances (devops private subnets)
   ↓
[Aurora Serverless v2] ← PostgreSQL (0.5-2 ACU, auto-scales)
```

**Key Features:**
- ✅ Frontend auto-scaling (different metrics)
- ✅ Backend fixed capacity
- ✅ Aurora Serverless v2 auto-scales compute
- ✅ All resources in private subnets
- ✅ SSM Session Manager access (no SSH keys)
- ✅ Multi-AZ high availability

---

## 🚀 Quick Start

### Choose Your Deployment Method:

#### **🎯 Option 1: Terraform (IaC) - RECOMMENDED** ⚡
**Automated, fast, repeatable infrastructure deployment**

```bash
cd AutoScaling-FrontEnd-CPU/terraform
# Follow terraform/README.md for complete setup
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

**Features:**
- ✅ **15-20 minute deployment** (vs 60+ minutes manual)
- ✅ **Automated resource creation** - 40+ AWS resources
- ✅ **Infrastructure as Code** - Version controlled, reusable
- ✅ **Modular design** - 7 modules for clean architecture
- ✅ **Easy cleanup** - `terraform destroy` removes everything
- ✅ **Production-ready** - Proper tagging, security, dependencies

📖 **Full Guide:** [AutoScaling-FrontEnd-CPU/terraform/README.md](AutoScaling-FrontEnd-CPU/terraform/README.md)

---

#### **🔧 Option 2: Manual Setup (AWS Console)**
**Step-by-step learning for understanding each component**

**Setup A: CPU-Based Scaling**
```bash
cd AutoScaling-FrontEnd-CPU
# Follow README.md for manual AWS Console setup
```

**Setup B: ALB Request Count Scaling**
```bash
cd AutoScaling-FrontEnd-ALB-request
# Follow README.md for manual AWS Console setup
```

**Features:**
- ✅ **Educational** - Learn each AWS service in detail
- ✅ **Two scaling strategies** - Compare CPU vs Request Count
- ✅ **AWS Console experience** - Hands-on with UI
- ⚠️ **Time-intensive** - 60-75 minutes per setup

---

### **Want to try both?** 
You can run both demos sequentially (not simultaneously):
1. Deploy with Terraform OR manual setup
2. Test auto-scaling behavior
3. Complete teardown
4. Try alternative scaling strategy (if manual)
5. Compare the results!

---

## ⏱️ Time Estimates

### Terraform Deployment (Recommended)
| Phase | Duration |
|-------|----------|
| Terraform Init & Plan | 2-3 min |
| Terraform Apply (Infrastructure) | 15-20 min* |
| Load Testing & Monitoring | 15-20 min |
| Terraform Destroy | 10-15 min |
| **Total** | **~45-60 min** |

### Manual Setup (AWS Console)
| Phase | Duration |
|-------|----------|
| Infrastructure Setup (Manual) | 35-50 min** |
| Application Deployment (Automated) | 5-10 min |
| Load Testing & Monitoring | 15-20 min |
| Teardown | 20-30 min |
| **Total** | **~75-110 min** |

*Aurora Serverless v2 creation takes 10-12 minutes (longest single step)  
**Faster because you already have VPC infrastructure (`devops-vpc`) in ap-south-1!

---

## 💰 Cost Estimates

**1-hour demo:** ~$2-3  
**24-hour demo:** ~$10-15

**Breakdown:**
- EC2 instances (4-6 × t3.micro): ~$0.50/hour
- Aurora Serverless v2: ~$0.24-1.92/hour
- ALB (2): ~$0.05/hour
- NAT Gateway: Already exists (devops-regional-nat)
- SSM VPC Endpoints: ~$0.03/hour
- Data transfer: Minimal

⚠️ **IMPORTANT:** Delete all resources after demo to avoid charges!

---

## 📊 What Gets Auto-Scaled

| Component | Setup 1 (CPU) | Setup 2 (ALB Request) | Method |
|-----------|---------------|----------------------|--------|
| **Frontend** | ✅ Yes (60% CPU) | ✅ Yes (1000 req/min) | Auto Scaling Group |
| **Backend** | ❌ No (2 fixed) | ❌ No (2 fixed) | Manual EC2 |
| **Database** | ✅ Yes (0.5-2 ACU) | ✅ Yes (0.5-2 ACU) | Aurora Serverless v2 |

---

## 🧪 Load Testing

Both setups include load testing scripts:

### **CPU-Based Test:**
```bash
./load-test/quick-test.sh http://your-alb-url.com
```
- 100 concurrent users
- 50,000 requests
- Targets CPU-intensive operations

### **ALB Request Test:**
```bash
./load-test/quick-test.sh http://your-alb-url.com
```
- 150 concurrent users
- 100,000 requests
- Targets high request volume

### **Real-time Monitoring:**
```bash
./load-test/monitor.sh <asg-name> <region>
```

---

## 📋 What's Included in Each Setup

Both folders contain:

```
AutoScaling-FrontEnd-[CPU|ALB-request]/
├── QUICK-DEMO-SETUP.md          # Step-by-step AWS Console guide
├── backend-userdata.sh           # Golden AMI prep script for backend
├── frontend-userdata.sh          # Golden AMI prep script for frontend
├── deploy-backend.sh             # Backend deployment script
├── deploy-frontend.sh            # Frontend deployment script
├── iam-policies.json             # IAM role configuration
├── TEARDOWN-CHECKLIST.md         # Complete cleanup guide
└── load-test/
    ├── quick-test.sh             # Load generation script
    └── monitor.sh                # Real-time ASG monitoring
```

---

## 🔧 Prerequisites

- AWS Account with admin access
- **Existing VPC**: `devops-vpc` in **ap-south-1** (Mumbai) region
- AWS CLI installed (for monitoring)
- Apache Bench (ab) for load testing
- Basic AWS Console knowledge
- GitHub repo: `https://github.com/sarowar-alam/3-tier-web-app-auto-scalling.git`

---

## 📚 Documentation

### **Infrastructure:**
- [Existing VPC Reference](EXISTING-VPC-REFERENCE.md) ⭐ **Start here!**

### **Setup Guides:**
- [CPU-Based Setup Guide](AutoScaling-FrontEnd-CPU/QUICK-DEMO-SETUP.md)
- [ALB Request Count Setup Guide](AutoScaling-FrontEnd-ALB-request/QUICK-DEMO-SETUP.md)

### **Teardown:**
- [CPU-Based Teardown Checklist](AutoScaling-FrontEnd-CPU/TEARDOWN-CHECKLIST.md)
- [ALB Request Teardown Checklist](AutoScaling-FrontEnd-ALB-request/TEARDOWN-CHECKLIST.md)

---

## 🎓 Learning Objectives

After completing these demos, you'll understand:

1. **Auto Scaling Groups (ASG)**
   - Launch templates
   - Scaling policies (target tracking)
   - Health checks and grace periods
   - Multi-AZ distribution

2. **Load Balancers (ALB)**
   - Target groups
   - Health checks
   - Request routing
   - Internal vs internet-facing

3. **Scaling Metrics**
   - CPU utilization
   - ALB request count per target
   - CloudWatch metrics
   - Scaling thresholds

4. **Aurora Serverless v2**
   - ACU-based scaling
   - Capacity management
   - Cost optimization

5. **Systems Manager (SSM)**
   - Session Manager
   - Parameter Store
   - VPC endpoints

6. **Security Best Practices**
   - Private subnets
   - Security groups
   - IAM roles
   - No SSH keys

---

## 🔄 Comparison Matrix

| Feature | CPU-Based | ALB Request Count |
|---------|-----------|-------------------|
| **Scaling Speed** | Fast (30-60s) | Moderate (60-120s) |
| **Predictability** | Low | High |
| **Capacity Planning** | Difficult | Easy |
| **Resource Efficiency** | Variable | Consistent |
| **Best Use Case** | Compute-heavy | Traffic-heavy |
| **Scaling Granularity** | Fine | Coarse |
| **CloudWatch Cost** | Standard | Standard |

---

## 🐛 Troubleshooting

### Common Issues:

**Problem:** Instances not scaling  
**Solution:** Check CloudWatch metrics, verify scaling policy configuration

**Problem:** Can't connect to instances  
**Solution:** Verify SSM VPC endpoints, check IAM role permissions

**Problem:** Health checks failing  
**Solution:** Verify security groups, check application logs via SSM

**Problem:** High costs  
**Solution:** Delete NAT Gateway and RDS first, follow teardown checklist

For detailed troubleshooting, see setup guides.

---

## 🧹 Cleanup

**⚠️ CRITICAL:** Always follow the teardown checklist to avoid unexpected charges!

### Terraform Cleanup (Recommended)
```bash
cd AutoScaling-FrontEnd-CPU/terraform
terraform destroy -auto-approve
# Verify all resources deleted in AWS Console
```

**Time:** ~10-15 minutes  
**Advantage:** Automated, ensures all resources are removed

### Manual Cleanup
Follow the detailed teardown checklists:
- [CPU-Based Setup Teardown](AutoScaling-FrontEnd-CPU/TEARDOWN-CHECKLIST.md)
- [ALB Request Count Setup Teardown](AutoScaling-FrontEnd-ALB-request/TEARDOWN-CHECKLIST.md)

**Time:** ~20-30 minutes  
**Important:** Must follow sequence to avoid orphaned resources

---

## 📚 Project Structure

```
3-tier-web-app-auto-scalling/
├── README.md                          # This file - Project overview
├── EXISTING-VPC-REFERENCE.md          # VPC infrastructure details
├── .gitignore                         # Git ignore rules
│
├── backend/                           # Node.js Express API source
├── frontend/                          # React + Vite UI source
├── database/                          # PostgreSQL setup scripts
│
├── AutoScaling-FrontEnd-CPU/         # CPU-based scaling setup
│   ├── README.md                      # Manual setup guide (CPU-based)
│   ├── TEARDOWN-CHECKLIST.md          # Manual teardown steps
│   ├── deploy-backend.sh              # Backend deployment script
│   ├── deploy-frontend.sh             # Frontend deployment script
│   ├── load-test/                     # Load testing scripts
│   └── terraform/                     # 🎯 TERRAFORM IaC
│       ├── README.md                  # Terraform deployment guide
│       ├── backend.hcl                # S3 backend configuration
│       ├── terraform.tfvars           # Your configuration values
│       ├── terraform.tfvars.example   # Template for students
│       ├── providers.tf               # AWS provider setup
│       ├── variables.tf               # Input variables
│       ├── main.tf                    # Root module orchestration
│       ├── outputs.tf                 # Infrastructure outputs
│       ├── data.tf                    # VPC data sources
│       └── modules/                   # 7 reusable modules
│           ├── network/               # VPC endpoints, security groups
│           ├── database/              # Aurora Serverless v2
│           ├── iam/                   # EC2 roles & policies
│           ├── parameter_store/       # SSM parameters
│           ├── load_balancing/        # ALBs & target groups
│           ├── compute_backend/       # Backend EC2 instances
│           └── compute_frontend/      # Frontend ASG
│
└── AutoScaling-FrontEnd-ALB-request/ # ALB request count scaling
    ├── README.md                      # Manual setup guide (ALB-based)
    ├── TEARDOWN-CHECKLIST.md          # Manual teardown steps
    └── [similar structure to CPU folder]
```

---

## 🎓 Learning Outcomes

After completing this project, you will understand:

### Infrastructure & Architecture
- ✅ 3-tier application architecture design
- ✅ Multi-AZ high availability patterns
- ✅ Private vs public subnet security
- ✅ VPC networking (NAT, IGW, endpoints)
- ✅ **Infrastructure as Code with Terraform**
- ✅ **Terraform module design patterns**

### Auto-Scaling Concepts
- ✅ CPU-based vs request-based scaling strategies
- ✅ Target tracking scaling policies
- ✅ Launch templates and ASG configuration
- ✅ Cooldown periods and warmup time
- ✅ CloudWatch metrics for scaling decisions

### AWS Services
- ✅ EC2 Auto Scaling Groups
- ✅ Application Load Balancers (public and internal)
- ✅ Aurora Serverless v2 auto-scaling compute
- ✅ Systems Manager (Session Manager, Parameter Store)
- ✅ VPC Endpoints for private access
- ✅ IAM roles and policies for EC2
- ✅ CloudWatch monitoring and alarms

### DevOps Practices
- ✅ Golden AMI creation workflow
- ✅ User-data scripts for bootstrapping
- ✅ Load testing and capacity planning
- ✅ **Terraform state management (S3 backend)**
- ✅ **Modular IaC architecture**
- ✅ Cost optimization strategies
- ✅ Proper resource teardown procedures

---

## 🚀 Next Steps & Enhancements

**Completed:**
- ✅ Manual AWS Console setup guides
- ✅ **Complete Terraform IaC implementation**
- ✅ **7 reusable Terraform modules**
- ✅ Two auto-scaling strategies (CPU & ALB request count)
- ✅ Load testing scripts
- ✅ Golden AMI workflow

**Future Enhancements:**
- 🔄 CI/CD pipeline with Jenkins/GitHub Actions
- 🔄 Terraform deployment for ALB request count setup
- 🔄 CloudWatch dashboards automation
- 🔄 HTTPS support with ACM certificates
- 🔄 Route53 DNS configuration
- 🔄 WAF integration for security
- 🔄 Multi-environment support (dev/staging/prod)
- 🔄 Packer templates for Golden AMI automation

---

## 📝 Notes

- Uses your **existing devops-vpc** infrastructure (ap-south-1)
- Both setups use **Golden AMIs** for faster boot times
- Application deployment is **fully automated** via user-data scripts
- Infrastructure setup is **manual** (no Terraform/CloudFormation)
- Designed for **1-hour demonstrations**
- Won't interfere with existing devops VPC resources
- Easily adaptable for production use

---

## 🤝 Contributing

This is a demonstration project for learning AWS auto-scaling concepts. Feel free to:
- Modify scaling thresholds
- Add monitoring dashboards
- Implement CI/CD pipelines
- Convert to Infrastructure as Code (Terraform)

---

## 📞 Support

For issues or questions:
1. Review the setup guide troubleshooting section
2. Check AWS CloudWatch logs and metrics
3. Verify all prerequisites are met
4. Ensure AWS CLI credentials are configured

---

## ✅ Success Checklist

After completing both demos, you should be able to:
- [ ] Explain the difference between CPU and request count scaling
- [ ] Create and configure Auto Scaling Groups
- [ ] Set up Application Load Balancers
- [ ] Use Aurora Serverless v2
- [ ] Generate and analyze load tests
- [ ] Monitor auto-scaling in real-time
- [ ] Choose the right scaling strategy for your app
- [ ] Clean up AWS resources completely

---

## 🎉 Ready to Start?

1. **Review your existing VPC** - Read [EXISTING-VPC-REFERENCE.md](EXISTING-VPC-REFERENCE.md)
2. **Choose your scaling strategy** (CPU or ALB request count)
3. **Open the QUICK-DEMO-SETUP.md** in your chosen folder
4. **Follow the step-by-step guide** (updated for devops-vpc in ap-south-1)
5. **Test and observe auto-scaling**
6. **Don't forget to tear down!**

**Happy auto-scaling!** 🚀

---
## 🧑‍💻 Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)
---
