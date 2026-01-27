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

Both setups use the same 3-tier architecture:

```
Internet
   ↓
[Public ALB] ← Frontend Load Balancer
   ↓
[Frontend ASG] ← 2-4 EC2 instances (AUTO-SCALES)
   ↓
[Internal ALB] ← Backend Load Balancer
   ↓
[Backend EC2] ← 2 fixed instances (no auto-scaling)
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

### Choose Your Setup:

#### **Option A: CPU-Based Scaling**
```bash
cd AutoScaling-FrontEnd-CPU
cat QUICK-DEMO-SETUP.md
```

#### **Option B: ALB Request Count Scaling**
```bash
cd AutoScaling-FrontEnd-ALB-request
cat QUICK-DEMO-SETUP.md
```

### **Want to try both?** 
You can run both demos sequentially (not simultaneously):
1. Complete Setup 1, test, teardown
2. Complete Setup 2, test, teardown
3. Compare the results!

---

## ⏱️ Time Estimates

| Phase | Duration |
|-------|----------|
| Infrastructure Setup (Manual) | 45-60 min |
| Application Deployment (Automated) | 5-10 min |
| Load Testing & Monitoring | 15-20 min |
| Teardown | 20-30 min |
| **Total** | **~90-120 min** |

---

## 💰 Cost Estimates

**1-hour demo:** ~$2-3  
**24-hour demo:** ~$10-15

**Breakdown:**
- EC2 instances (4-6 × t3.micro): ~$0.50/hour
- Aurora Serverless v2: ~$0.24-1.92/hour
- ALB (2): ~$0.05/hour
- NAT Gateway: ~$0.045/hour
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
- AWS CLI installed (for monitoring)
- Apache Bench (ab) for load testing
- Basic AWS Console knowledge
- GitHub repo access

---

## 📚 Documentation

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

**Quick cleanup commands:**
```bash
# Delete ASG (will terminate instances)
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name <name> --force-delete

# Delete ALBs
aws elbv2 delete-load-balancer --load-balancer-arn <arn>

# Delete Aurora cluster
aws rds delete-db-cluster --db-cluster-identifier <name> --skip-final-snapshot

# Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id <id>
```

**Or follow the detailed checklists for manual deletion.**

---

## 📝 Notes

- Both setups use **Golden AMIs** for faster boot times
- Application deployment is **fully automated** via user-data scripts
- Infrastructure setup is **manual** (no Terraform/CloudFormation)
- Designed for **1-hour demonstrations**
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

1. **Choose your scaling strategy** (CPU or ALB request count)
2. **Open the QUICK-DEMO-SETUP.md** in your chosen folder
3. **Follow the step-by-step guide**
4. **Test and observe auto-scaling**
5. **Don't forget to tear down!**

**Happy auto-scaling!** 🚀

---

**Last Updated:** January 2026  
**AWS Services:** EC2, ALB, Auto Scaling, Aurora Serverless v2, Systems Manager, CloudWatch
