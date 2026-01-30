# AWS Infrastructure Teardown Checklist

⚠️ **IMPORTANT**: Follow this sequence to avoid orphaned resources and unnecessary charges.

## Teardown Order (Critical!)

### 1. Auto Scaling Groups
- [ ] Go to **EC2 > Auto Scaling Groups**
- [ ] Select **Frontend ASG** → Actions → Delete
- [ ] Select **Backend ASG** → Actions → Delete
- [ ] Wait for all EC2 instances to terminate (~2-3 minutes)
- [ ] Verify: EC2 > Instances shows 0 instances from ASGs

### 2. Launch Templates
- [ ] Go to **EC2 > Launch Templates**
- [ ] Select **Frontend Launch Template** → Actions → Delete
- [ ] Select **Backend Launch Template** → Actions → Delete

### 3. Target Groups
- [ ] Go to **EC2 > Target Groups**
- [ ] Select **Frontend Target Group** → Actions → Delete
- [ ] Select **Backend Target Group** → Actions → Delete

### 4. Application Load Balancers
- [ ] Go to **EC2 > Load Balancers**
- [ ] Select **Frontend ALB** → Actions → Delete
- [ ] Select **Backend ALB** → Actions → Delete
- [ ] Wait ~5 minutes for deletion to complete

### 5. Aurora Serverless Database
- [ ] Go to **RDS > Databases**
- [ ] Select **bmi-aurora-cluster** → Actions → Delete
- [ ] **UNCHECK** "Create final snapshot" (for demo purposes)
- [ ] **UNCHECK** "Retain automated backups"
- [ ] Type confirmation: `delete me`
- [ ] Wait ~10-15 minutes for deletion

### 6. DB Subnet Group
- [ ] Go to **RDS > Subnet Groups**
- [ ] Select **bmi-db-subnet-group** → Delete
- [ ] Confirm deletion

### 7. VPC Endpoints (for SSM)
- [ ] Go to **VPC > Endpoints**
- [ ] Select endpoints with names containing:
  - `ssm`
  - `ec2messages`
  - `ssmmessages`
- [ ] Actions → Delete endpoint (for each)

### 8. NAT Gateway
- [ ] Go to **VPC > NAT Gateways**
- [ ] Select NAT Gateway → Actions → Delete NAT gateway
- [ ] Wait ~5 minutes for deletion

### 9. Elastic IPs
- [ ] Go to **VPC > Elastic IPs**
- [ ] Select any unassociated Elastic IPs
- [ ] Actions → Release Elastic IP addresses

### 10. Internet Gateway
- [ ] Go to **VPC > Internet Gateways**
- [ ] Select your Internet Gateway
- [ ] Actions → Detach from VPC
- [ ] Then Actions → Delete internet gateway

### 11. Security Groups
- [ ] Go to **VPC > Security Groups**
- [ ] Delete in this order (to avoid dependency issues):
  - [ ] Frontend-SG
  - [ ] Backend-SG
  - [ ] Frontend-ALB-SG
  - [ ] Backend-ALB-SG
  - [ ] Aurora-SG
- [ ] **Note**: Cannot delete default security group

### 12. Subnets
- [ ] Go to **VPC > Subnets**
- [ ] Select all custom subnets (public and private)
- [ ] Actions → Delete subnet

### 13. Route Tables
- [ ] Go to **VPC > Route Tables**
- [ ] Select custom route tables (NOT the main route table)
- [ ] Actions → Delete route table

### 14. VPC
- [ ] Go to **VPC > Your VPCs**
- [ ] Select your VPC
- [ ] Actions → Delete VPC
- [ ] **Note**: This will auto-delete remaining resources

### 15. CloudWatch Resources
- [ ] Go to **CloudWatch > Alarms**
- [ ] Select all alarms → Actions → Delete
- [ ] Go to **CloudWatch > Dashboards**
- [ ] Delete any custom dashboards

### 16. Systems Manager Parameter Store
- [ ] Go to **Systems Manager > Parameter Store**
- [ ] Select parameters:
  - [ ] `/bmi-app/db-host`
  - [ ] `/bmi-app/db-name`
  - [ ] `/bmi-app/db-user`
  - [ ] `/bmi-app/db-password`
  - [ ] `/bmi-app/backend-alb-url`
- [ ] Actions → Delete

### 17. IAM Role (Optional)
- [ ] Go to **IAM > Roles**
- [ ] Search for **EC2RoleForBMIApp**
- [ ] Delete role
- [ ] **Note**: Only if you won't use it again

### 18. AMIs and Snapshots (Optional)
- [ ] Go to **EC2 > AMIs**
- [ ] Select **Frontend Golden AMI** → Actions → Deregister
- [ ] Select **Backend Golden AMI** → Actions → Deregister
- [ ] Go to **EC2 > Snapshots**
- [ ] Select snapshots associated with AMIs → Actions → Delete

### 19. S3 Buckets (If Created)
- [ ] Go to **S3**
- [ ] Check for ALB access logs bucket
- [ ] Empty bucket → Delete bucket

### 20. CloudWatch Logs (Optional)
- [ ] Go to **CloudWatch > Log groups**
- [ ] Delete log groups with prefix `/aws/ec2/` or `/aws/rds/`

---

## Verification Commands (AWS CLI)

Run these to verify everything is deleted:

```bash
# Check for running EC2 instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId'

# Check for Auto Scaling Groups
aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[].AutoScalingGroupName'

# Check for Load Balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'

# Check for RDS instances
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'

# Check for Aurora clusters
aws rds describe-db-clusters --query 'DBClusters[].DBClusterIdentifier'

# Check for NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'NatGateways[].NatGatewayId'

# Check for VPCs (excluding default)
aws ec2 describe-vpcs --filters "Name=isDefault,Values=false" --query 'Vpcs[].VpcId'
```

---

## Cost Verification

After teardown, check:
- [ ] **AWS Cost Explorer**: No new charges appearing
- [ ] **Billing Dashboard**: Current month charges stopped
- [ ] Wait 24 hours and verify no surprises

---

## Common Mistakes to Avoid

❌ **Don't skip the order** - Dependencies matter!
❌ **Don't forget NAT Gateway** - It charges hourly even when idle
❌ **Don't leave RDS running** - Most expensive component
❌ **Don't forget Elastic IPs** - Charges when not associated
❌ **Don't miss VPC Endpoints** - Small but adds up

---

## Estimated Time

- Full teardown: **20-30 minutes**
- With verification: **30-45 minutes**

---

## Troubleshooting

### "Cannot delete security group - has dependent objects"
- Wait 5 more minutes, resources may still be terminating
- Check for network interfaces still attached
- Delete ALBs first, then try again

### "Cannot delete VPC - has dependencies"
- Ensure NAT Gateway is deleted
- Ensure all VPC Endpoints are deleted
- Check for orphaned ENIs (Elastic Network Interfaces)

### "RDS deletion taking too long"
- Normal: Aurora can take 10-15 minutes
- Check RDS > Events for progress
- If stuck, contact AWS support

---

## Final Check ✅

All resources deleted when:
- [ ] No running EC2 instances (except default if any)
- [ ] No ALBs in any region
- [ ] No RDS/Aurora databases
- [ ] No NAT Gateways
- [ ] VPC deleted or only default VPC remains
- [ ] No unusual charges in billing dashboard

---

**Done!** 🎉 Your demo infrastructure is fully cleaned up.

---
## 🧑‍💻 Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)
---
