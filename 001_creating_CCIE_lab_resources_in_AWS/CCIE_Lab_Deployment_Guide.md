# CCIE Lab Environment Deployment Guide

## Overview
This document details the complete process of deploying a CCIE Enterprise Infrastructure lab environment on AWS using EC2 instances in the Manila local zone, including multi-part archive handling, S3 integration, and AMI creation strategy.

## Project Requirements
- Deploy CCIE Enterprise Infrastructure lab environment
- Use Manila local zone for low latency
- Handle 34GB multi-part archive files
- Create reusable AMI for cost optimization
- Work within 16 vCPU service limit constraint

## Architecture Overview
- **Location**: AWS Manila Local Zone (ap-southeast-1-mnl-1a)
- **Instance Type**: c5.4xlarge (16 vCPUs, 32GB RAM)
- **Storage**: 150GB gp2 volume
- **Network**: Public subnet with internet gateway
- **IAM**: Custom role for S3 access
- **Files**: 34GB CCIE lab environment in .ova format

## Step-by-Step Deployment Process

### 1. Infrastructure Discovery and Planning

#### 1.1 Subnet Discovery
```bash
aws ec2 describe-subnets --region ap-southeast-1 --filters "Name=availability-zone,Values=ap-southeast-1-mnl-1a"
```
**Result**: Located subnet `subnet-0edaf93ed07022542` in Manila local zone

#### 1.2 Instance Type Analysis
```bash
aws ec2 describe-instance-type-offerings --location-type availability-zone --filters "Name=location,Values=ap-southeast-1-mnl-1a" --region ap-southeast-1
```
**Available Instance Types in Manila Local Zone**:
- c5.large, c5.xlarge, c5.2xlarge, c5.4xlarge, c5.12xlarge
- m5.large, m5.xlarge, m5.2xlarge, m5.4xlarge, m5.12xlarge
- r5.large, r5.xlarge, r5.2xlarge, r5.4xlarge, r5.12xlarge

**Selected**: c5.4xlarge (16 vCPUs, 32GB RAM) - optimal for CCIE lab requirements

### 2. IAM Role Configuration

#### 2.1 Create IAM Role
```bash
aws iam create-role --role-name CCIE-Lab-S3-Access-Role --assume-role-policy-document '{
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
}' --region ap-southeast-1
```

#### 2.2 Attach S3 Policy
```bash
aws iam attach-role-policy --role-name CCIE-Lab-S3-Access-Role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --region ap-southeast-1
```

#### 2.3 Create Instance Profile
```bash
aws iam create-instance-profile --instance-profile-name CCIE-Lab-S3-Access-Profile --region ap-southeast-1
aws iam add-role-to-instance-profile --instance-profile-name CCIE-Lab-S3-Access-Profile --role-name CCIE-Lab-S3-Access-Role --region ap-southeast-1
```

### 3. EC2 Instance Deployment

#### 3.1 UserData Script
```bash
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install 7zip for multi-part archive extraction
yum install -y p7zip p7zip-plugins

# Download files from S3
aws s3 cp s3://ccie-lab-files-ken/ /home/ec2-user/ccie-files/ --recursive

# Set permissions
chown -R ec2-user:ec2-user /home/ec2-user/ccie-files/
```

#### 3.2 Instance Launch
```bash
aws ec2 run-instances \
  --image-id ami-047126e50991d067b \
  --instance-type c5.4xlarge \
  --key-name MyKeyPair \
  --security-group-ids sg-0123456789abcdef0 \
  --subnet-id subnet-0edaf93ed07022542 \
  --associate-public-ip-address \
  --iam-instance-profile Name=CCIE-Lab-S3-Access-Profile \
  --block-device-mappings '[{
    "DeviceName": "/dev/xvda",
    "Ebs": {
      "VolumeSize": 150,
      "VolumeType": "gp2",
      "DeleteOnTermination": true
    }
  }]' \
  --user-data file://userdata.sh \
  --region ap-southeast-1
```

**Result**: Instance `i-0a0562d9fad11244b` created successfully

#### 3.3 Associate IAM Role
```bash
aws ec2 associate-iam-instance-profile --instance-id i-0a0562d9fad11244b --iam-instance-profile Name=CCIE-Lab-S3-Access-Profile --region ap-southeast-1
```

### 4. File Management and Extraction

#### 4.1 Multi-Part Archive Structure
- **Main file**: `eve-ng ccie ei v1.1_splitted.zip`
- **Parts**: `.z01` through `.z16` (17 parts total)
- **Total size**: ~34GB
- **Extracted file**: `eve-ng ccie ei v1.1.ova` (34 GiB)

#### 4.2 SSH Connection and File Operations
```bash
# Connect to instance
ssh -i MyKeyPair.pem ec2-user@96.0.146.209

# Verify downloads
ls -la /home/ec2-user/ccie-files/
total 35651584
-rw-r--r-- 1 ec2-user ec2-user 2147483648 Aug  2 18:45 eve-ng ccie ei v1.1_splitted.z01
-rw-r--r-- 1 ec2-user ec2-user 2147483648 Aug  2 18:45 eve-ng ccie ei v1.1_splitted.z02
...
-rw-r--r-- 1 ec2-user ec2-user 1073741824 Aug  2 18:45 eve-ng ccie ei v1.1_splitted.z16
-rw-r--r-- 1 ec2-user ec2-user 2147483648 Aug  2 18:45 eve-ng ccie ei v1.1_splitted.zip

# Extract multi-part archive
7za x "eve-ng ccie ei v1.1_splitted.zip"

# Verify extraction
ls -lh "eve-ng ccie ei v1.1.ova"
-rw-r--r-- 1 ec2-user ec2-user 34G Aug  2 18:50 eve-ng ccie ei v1.1.ova
```

### 5. Technical Specifications

#### 5.1 Instance Configuration
- **Instance ID**: i-0a0562d9fad11244b
- **Instance Type**: c5.4xlarge
- **vCPUs**: 16
- **Memory**: 32 GB
- **Network Performance**: Up to 10 Gbps
- **EBS Bandwidth**: Up to 4,750 Mbps
- **Public IP**: 96.0.146.209

#### 5.2 Storage Configuration
- **Root Volume**: 150GB gp2 (gp3 not supported in Manila local zone)
- **IOPS**: 450 (3 IOPS per GB for gp2)
- **Throughput**: 125 MB/s baseline

#### 5.3 Network Configuration
- **VPC**: Default VPC
- **Subnet**: subnet-0edaf93ed07022542 (Manila Local Zone)
- **Availability Zone**: ap-southeast-1-mnl-1a
- **Public IP**: Enabled
- **Security Group**: Default with SSH access

### 6. Cost Optimization Strategy

#### 6.1 AMI Creation Approach
1. **Setup Phase**: Deploy instance with all required software and files
2. **Configuration Phase**: Install and configure CCIE lab environment
3. **AMI Creation**: Create custom AMI from configured instance
4. **Instance Termination**: Terminate original instance to save costs
5. **Lab Usage**: Launch new instances from AMI when needed

#### 6.2 Cost Analysis
- **c5.4xlarge**: ~$0.68/hour in Manila local zone
- **Storage**: 150GB gp2 ~$15/month
- **Data Transfer**: Minimal for local zone usage
- **AMI Storage**: ~$1.50/month for 150GB snapshot

### 7. Manila Local Zone Considerations

#### 7.1 Limitations
- Limited instance types compared to regular AZs
- No gp3 storage support
- Fewer AWS services available
- Higher pricing than regular AZs

#### 7.2 Benefits
- Ultra-low latency for Manila users
- Local data residency
- Reduced network hops
- Better performance for latency-sensitive applications

### 8. Service Limits and Constraints

#### 8.1 vCPU Limits
- **Current Limit**: 16 vCPUs region-wide
- **Impact**: Limits instance selection and concurrent usage
- **Solution**: Request limit increase if needed

#### 8.2 Instance Type Availability
- **Compute Optimized**: c5 family available
- **General Purpose**: m5 family available
- **Memory Optimized**: r5 family available
- **Missing**: Latest generation instances (c6i, m6i, etc.)

### 9. Security Best Practices

#### 9.1 IAM Configuration
- Principle of least privilege applied
- Instance-specific IAM roles
- No hardcoded credentials
- S3 access through IAM roles only

#### 9.2 Network Security
- Security groups with minimal required access
- SSH key-based authentication
- Public IP only when necessary
- Consider VPN for production environments

### 10. Troubleshooting Guide

#### 10.1 Common Issues
- **Multi-part extraction failures**: Use 7zip instead of unzip
- **S3 access denied**: Verify IAM role attachment
- **Instance launch failures**: Check service limits
- **Storage space**: Monitor disk usage during extraction

#### 10.2 Monitoring Commands
```bash
# Check disk space
df -h

# Monitor extraction progress
watch -n 5 'ls -lh *.ova'

# Check IAM role
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Verify S3 access
aws s3 ls s3://ccie-lab-files-ken/
```

### 11. Next Steps and Recommendations

#### 11.1 Immediate Actions
1. Complete .ova file import into virtualization platform
2. Configure CCIE lab environment
3. Create AMI from configured instance
4. Test AMI deployment process

#### 11.2 Future Enhancements
- Automate AMI creation with Lambda
- Implement cost monitoring and alerts
- Consider Reserved Instances for long-term usage
- Explore Spot Instances for cost savings

#### 11.3 Scaling Considerations
- Request vCPU limit increase if needed
- Consider multiple smaller instances vs. single large instance
- Implement auto-scaling for variable workloads
- Use Application Load Balancer for distributed labs

## Conclusion

This deployment successfully created a CCIE Enterprise Infrastructure lab environment in AWS Manila Local Zone, handling the complexities of multi-part archive extraction, IAM role configuration, and storage optimization. The solution provides a foundation for cost-effective, scalable CCIE lab training with the flexibility to create reusable AMIs for future deployments.

The key success factors were:
- Proper instance sizing within service limits
- Correct IAM role configuration for S3 access
- Appropriate tool selection for multi-part archive handling
- Strategic use of Manila Local Zone for optimal performance
- Cost optimization through AMI-based deployment strategy

This approach can be replicated for similar lab environments and serves as a template for deploying complex virtualized training environments on AWS infrastructure.
