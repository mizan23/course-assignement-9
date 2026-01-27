# AWS Auto-Scaling Demo - Frontend ALB Request Count Scaling

**Quick 1-Hour Setup Guide for BMI Health Tracker**

This guide sets up a 3-tier architecture with **Frontend Auto-Scaling based on ALB Request Count per Target** (1000 requests/minute target).

---

## Architecture Overview

```
Internet
   ↓
[Public ALB] ← Frontend Load Balancer
   ↓
[Frontend ASG] ← 2-4 EC2 instances (Auto-scales on 1000 req/min per target)
   ↓ (proxies /api requests)
[Internal ALB] ← Backend Load Balancer
   ↓
[Backend EC2] ← 2 fixed instances
   ↓
[Aurora Serverless v2] ← PostgreSQL (0.5-2 ACU, auto-scales)
```

**Key Features:**
- ✅ Frontend auto-scales based on ALB Request Count (1000 req/min per target)
- ✅ Backend fixed at 2 instances (no auto-scaling)
- ✅ Aurora Serverless v2 auto-scales compute (0.5→2 ACU)
- ✅ SSM Session Manager for secure access (no SSH keys)
- ✅ All private subnets (frontend + backend in private)
- ✅ Multi-AZ setup for high availability

**Difference from CPU-based:**
- Scales based on actual traffic volume, not CPU usage
- More predictable scaling behavior for web applications
- Better for traffic-heavy but CPU-light workloads

**Estimated Costs:**
- ~$2-3 for 1-hour demo
- ~$10-15 if left running for 24 hours

---

## Prerequisites

- AWS Account with admin access
- AWS CLI installed locally (for monitoring)
- Basic understanding of AWS Console
- GitHub repo: `https://github.com/sarowar-alam/3-tier-web-app-auto-scalling.git`

---

## Phase 1-6: Use Existing Infrastructure & Follow CPU-Based Setup

**NOTE:** You already have the VPC infrastructure! We'll use your existing `devops-vpc` in **ap-south-1** region.

**Phase 1:** Use existing VPC (see CPU-based guide - already updated)
- ✅ VPC: `devops-vpc` (10.0.0.0/16)
- ✅ Region: `ap-south-1` (Mumbai)
- ✅ NAT Gateway: `devops-regional-nat` (exists)
- ✅ Internet Gateway: `devops-igw` (exists)
- ⚠️ Need to create: SSM VPC endpoints only

**Phases 2-6:** Follow [AutoScaling-FrontEnd-CPU/QUICK-DEMO-SETUP.md](../AutoScaling-FrontEnd-CPU/QUICK-DEMO-SETUP.md):
- Phase 2: Database Setup (15 minutes) - Use `devops-vpc` subnets
- Phase 3: IAM Role Setup (5 minutes) - Identical
- Phase 4: Parameter Store Configuration (3 minutes) - Identical
- Phase 5: Security Groups Setup (5 minutes) - Use `devops-vpc`
- Phase 6: Create Golden AMIs (20 minutes) - Use `devops-subnet-public1-ap-south-1a`

**The difference starts from Phase 7 onwards with the ALB request count scaling configuration.**

---

## Phase 7: Application Load Balancers (10 minutes)

### Step 7.1-7.3: Backend ALB Setup (Identical)

Follow steps 7.1-7.3 from CPU-based setup to create:
- Backend Target Group (port 3000, /health check)
- Backend Internal ALB
- Update Parameter Store with Backend ALB URL

### Step 7.4: Create Frontend Target Group

1. Go to **EC2** → **Target Groups** → **Create target group**
2. Configure:
   - **Target type**: `Instances`
   - **Name**: `bmi-frontend-tg`
   - **Protocol**: `HTTP`, Port: `80`
   - **VPC**: Select `devops-vpc`
   - **Health check**:
     - Path: `/health`
     - Interval: `10 seconds`
     - Timeout: `5 seconds`
     - Healthy threshold: `2`
     - Unhealthy threshold: `3`
3. Click **Next**
4. **Don't register any targets yet**
5. Click **Create target group**

### Step 7.5: Create Frontend ALB (Public)

1. Go to **EC2** → **Load Balancers** → **Create Load Balancer**
2. Choose **Application Load Balancer**
3. Configure:
   - **Name**: `bmi-frontend-alb`
   - **Scheme**: `Internet-facing` ⚠️
   - **IP address type**: `IPv4`
   - **VPC**: Select `devops-vpc`
   - **Mappings**: Select **both AZs** and **both public subnets**:
     - ap-south-1a: `devops-subnet-public1-ap-south-1a`
     - ap-south-1b: `devops-subnet-public2-ap-south-1b`
   - **Security groups**: Select `frontend-alb-sg`
   - **Listeners**: HTTP (80) → Forward to `bmi-frontend-tg`
4. Click **Create load balancer**
5. Wait ~2 minutes
6. **Copy the DNS name** (this is your application URL!)
7. **Copy the ARN suffix** (needed for CloudWatch metrics) - e.g., `app/bmi-frontend-alb/1234567890abcdef`

---

## Phase 8: Backend EC2 Instances (Same as CPU-based)

Follow **Phase 8** from CPU-based setup to:
- Launch 2 backend instances manually in private subnets
- Register them with backend target group
- Verify health checks pass

---

## Phase 9: Frontend Auto Scaling Group with Request Count Scaling (15 minutes)

### Step 9.1: Create Launch Template

1. Go to **EC2** → **Launch Templates** → **Create launch template**
2. Configure:

**Template name**: `bmi-frontend-lt`
**Description**: `Launch template for frontend auto-scaling (ALB request count)`

**AMI**: Select `bmi-frontend-golden-ami`
**Instance type**: `t3.micro`

**Key pair**: Not needed

**Network settings**:
- **Subnet**: Don't include in template
- **Security groups**: Select `frontend-ec2-sg`

**Advanced details**:
- **IAM instance profile**: Select `EC2RoleForBMIApp`
- **Metadata version**: `V2 only (token required)`
- **User data**:

```bash
#!/bin/bash
wget https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-ALB-request/deploy-frontend.sh
chmod +x deploy-frontend.sh
./deploy-frontend.sh
```

3. Click **Create launch template**

### Step 9.2: Create Auto Scaling Group

1. Go to **EC2** → **Auto Scaling Groups** → **Create Auto Scaling group**
2. **Step 1: Choose launch template**
   - **Name**: `bmi-frontend-asg-alb`
   - **Launch template**: Select `bmi-frontend-lt`
   - Click **Next**

3. **Step 2: Network**
   - **VPC**: Select `devops-vpc`
   - **Availability Zones and subnets**: Select **both private subnets**:
     - `devops-subnet-private1-ap-south-1a`
     - `devops-subnet-private2-ap-south-1b`
   - Click **Next**

4. **Step 3: Load balancing**
   - **Load balancing**: `Attach to an existing load balancer`
   - **Choose target groups**: Select `bmi-frontend-tg`
   - **Health checks**:
     - ELB health check: `Enable`
     - Health check grace period: `300 seconds` (5 minutes)
   - Click **Next**

5. **Step 4: Group size and scaling** ⚠️ **IMPORTANT - Different from CPU-based**
   
   **Group size:**
   - **Desired capacity**: `2`
   - **Min**: `1`
   - **Max**: `4`
   
   **Scaling policies**: `Target tracking scaling policy`
   - **Policy name**: `alb-request-count-tracking`
   - **Metric type**: `Application Load Balancer request count per target` ⚠️
   - **Target value**: `1000` (requests per minute per instance)
   - **Instances need**: `60` seconds warmup
   
   Click **Next**

6. **Step 5: Notifications** - Skip
7. **Step 6: Tags**
   - Add tag: Key=`Name`, Value=`bmi-frontend-asg-alb-instance`
8. Click **Next** → **Create Auto Scaling Group**

### Step 9.3: Verify Frontend Deployment

1. Wait ~5-7 minutes for instances to launch and deploy
2. Go to **Target Groups** → `bmi-frontend-tg` → **Targets** tab
3. Verify 2 instances are `healthy`
4. Go to **Load Balancers** → Copy Frontend ALB DNS name
5. Open in browser: `http://<frontend-alb-dns>.elb.amazonaws.com`
6. You should see the BMI Health Tracker app! 🎉

---

## Phase 10: Load Testing and Monitoring (15 minutes)

### Step 10.1: Setup Load Testing (On Your Local Machine)

1. Install Apache Bench:
   - **macOS**: Pre-installed
   - **Linux**: `sudo yum install httpd-tools` or `sudo apt-get install apache2-utils`
   - **Windows**: Use WSL or download from Apache website

2. Download test scripts:

```bash
wget https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-ALB-request/load-test/quick-test.sh
chmod +x quick-test.sh

wget https://raw.githubusercontent.com/sarowar-alam/3-tier-web-app-auto-scalling/main/AutoScaling-FrontEnd-ALB-request/load-test/monitor.sh
chmod +x monitor.sh
```

### Step 10.2: Start Monitoring

Open a **second terminal** and run:

```bash
./monitor.sh bmi-frontend-asg-alb ap-south-1
```

This will show real-time ASG status and instance metrics.

### Step 10.3: Run Load Test

In the **first terminal**:

```bash
./quick-test.sh http://<frontend-alb-dns>.elb.amazonaws.com
```

**What to expect:**
1. **0-1 minute**: Warmup, establishing baseline traffic
2. **1-3 minutes**: Request count climbs to 2000+ req/min (2 instances × 1000 target)
3. **3-5 minutes**: Request count exceeds 2000 (> 1000 per instance), ASG triggers scale-out
4. **5-7 minutes**: New instances launch, deploy, and register
5. **7-9 minutes**: Load redistributed, ~1000 req/min per instance maintained
6. **After test ends**: Wait 5-7 minutes, ASG scales in (terminates excess instances)

### Step 10.4: Monitor in AWS Console

Open these tabs:

1. **Auto Scaling Group Activity**:
   - EC2 → Auto Scaling Groups → `bmi-frontend-asg-alb` → Activity tab
   - Watch for "Launching a new EC2 instance" messages

2. **CloudWatch Metrics** (Most Important for ALB Request Count):
   - CloudWatch → Metrics → ApplicationELB
   - Select your load balancer
   - Choose **RequestCountPerTarget** metric
   - Set statistic to **Sum** and period to **1 minute**
   - Watch the graph climb above 1000

3. **Target Group Health**:
   - EC2 → Target Groups → `bmi-frontend-tg` → Targets tab
   - Watch new instances appear and become healthy

---

## Phase 11: Verification and Testing (5 minutes)

### Verify Request Count Scaling Works:

**Expected Behavior:**
- Start: 2 instances, ~1000 req/min each = 2000 total
- During load: 4000+ req/min generated
- Scaling: When average > 1000 req/min per instance, scale out
- Result: 3-4 instances, load distributed

**Check these:**
- [ ] Frontend ALB accessible via browser
- [ ] App loads and displays UI correctly
- [ ] Can submit measurements via form
- [ ] Backend API responding
- [ ] CloudWatch shows RequestCountPerTarget > 1000
- [ ] ASG activity shows scaling events
- [ ] Instances scale up during load
- [ ] Instances scale down after load stops

### Compare with CPU-Based Scaling:

**ALB Request Count Advantages:**
- ✅ More predictable - scales purely on traffic
- ✅ Better for web apps with variable CPU usage
- ✅ Direct correlation with user experience
- ✅ Easier to calculate capacity needs

**CPU-Based Advantages:**
- ✅ Works for any workload type
- ✅ Protects against compute-intensive requests
- ✅ Simpler to understand

### Test Aurora Auto-Scaling:

(Same as CPU-based setup)

1. Go to **RDS** → **Databases** → `bmi-aurora-cluster`
2. Click **Monitoring** tab
3. Check **Serverless Database Capacity** metric
4. During load test, capacity should increase from 0.5 ACU → 1-2 ACU

---

## Troubleshooting

### Scaling not triggered?
- **Check CloudWatch**: Verify RequestCountPerTarget metric exists
- **Check Target Group**: Ensure instances are healthy
- **Wait longer**: Request count scaling can take 2-3 minutes to trigger
- **Verify load**: Ensure load test is generating enough requests

### RequestCountPerTarget metric not showing?
- Wait 5-10 minutes after ALB creation
- Ensure target group has healthy instances
- Refresh CloudWatch metrics console
- Check correct load balancer and target group selected

### Instances not receiving traffic?
- Check ALB listener rules
- Verify target group health checks passing
- Check security group rules (ALB → EC2 port 80)
- Verify instances are in correct subnets

### Can't connect via SSM?
(Same as CPU-based setup - see troubleshooting section)

---

## Key Differences from CPU-Based Scaling

| Aspect | CPU-Based | ALB Request Count |
|--------|-----------|-------------------|
| **Scaling Metric** | CPU Utilization | Requests per Minute |
| **Target Value** | 60% CPU | 1000 req/min |
| **Best For** | Compute-intensive apps | Traffic-heavy web apps |
| **Predictability** | Variable (depends on workload) | High (traffic-based) |
| **Response Time** | Fast (CPU spikes quickly) | Moderate (traffic aggregated) |
| **Capacity Planning** | Harder | Easier (calculate from traffic) |

---

## Load Testing Comparison

**CPU-Based Test:**
- 100 concurrent connections
- Focuses on CPU-intensive operations
- Triggers on compute load

**ALB Request Count Test:**
- 150 concurrent connections
- Focuses on request volume
- Triggers on traffic volume

---

## Cost Optimization

(Same as CPU-based setup)

**During demo:**
- Use t3.micro instances ($0.0104/hour)
- Single NAT Gateway ($0.045/hour)
- Aurora Serverless v2 minimal ACUs

**After demo:**
- **DELETE EVERYTHING** using [TEARDOWN-CHECKLIST.md](TEARDOWN-CHECKLIST.md)

---

## Next Steps

1. **Compare both methods** - Run both CPU and ALB request demos
2. **Test different thresholds** - Try 500 req/min vs 1000 req/min
3. **Monitor costs** - Track which method is more cost-effective
4. **Experiment with mixed policies** - Combine CPU and request count
5. **CLEANUP** - Follow [TEARDOWN-CHECKLIST.md](TEARDOWN-CHECKLIST.md)

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
│                     (Users sending requests)                 │
└──────────────────────────┬──────────────────────────────────┘
                           │
                  ┌────────▼─────────┐
                  │  Public ALB      │ (Internet-facing)
                  │  Port 80         │
                  │  [Tracks Request │
                  │   Count/Target]  │
                  └────────┬─────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │ (1000 req/min)   │ (1000 req/min)   │ (scales when > 1000)
   ┌────▼────┐        ┌────▼────┐       ┌────▼────┐
   │Frontend │        │Frontend │       │Frontend │
   │EC2      │        │EC2      │       │EC2      │
   │(nginx)  │        │(nginx)  │       │(nginx)  │
   └────┬────┘        └────┬────┘       └────┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │ /api proxy
                  ┌────────▼─────────┐
                  │ Internal ALB     │ (private)
                  │ Port 80          │
                  └────────┬─────────┘
                           │
                  ┌────────┼─────────┐
                  │        │         │
             ┌────▼────┐  ┌▼────────┐
             │Backend  │  │Backend  │
             │EC2      │  │EC2      │
             │Node/PM2 │  │Node/PM2 │
             └────┬────┘  └┬────────┘
                  │        │
                  └────┬───┘
                       │
              ┌────────▼────────┐
              │ Aurora          │
              │ Serverless v2   │
              │ PostgreSQL      │
              │ (0.5-2 ACU)     │
              └─────────────────┘
```

---

## Summary

**What You've Built:**
- ✅ 3-tier auto-scaling architecture
- ✅ Frontend ASG with ALB request count scaling (1000 req/min per target)
- ✅ Backend on fixed EC2 instances (2)
- ✅ Aurora Serverless v2 with auto-scaling compute
- ✅ Multi-AZ high availability
- ✅ Private subnets with SSM access
- ✅ Comparison-ready with CPU-based setup

**Key Learnings:**
- Request count scaling is ideal for web applications
- More predictable than CPU-based scaling
- Easier capacity planning (traffic × response time = capacity)
- Direct correlation with user experience

**Total Setup Time:** ~60-75 minutes
**Demo Time:** 15-20 minutes
**Teardown Time:** 20-30 minutes

---

## Support

For issues with this setup:
1. Check [Troubleshooting](#troubleshooting) section
2. Review CloudWatch RequestCountPerTarget metrics
3. Compare with CPU-based setup behavior
4. Verify target group configuration

**Remember to clean up!** See [TEARDOWN-CHECKLIST.md](TEARDOWN-CHECKLIST.md)

---

**Demo complete! 🎉** 

Now you can compare CPU-based vs ALB request count scaling!
