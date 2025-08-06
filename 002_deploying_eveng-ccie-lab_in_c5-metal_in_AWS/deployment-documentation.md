# EVE-NG Deployment Documentation

## Overview
This document outlines the complete deployment process for setting up an EVE-NG environment on AWS EC2 using KVM virtualization, from initial instance launch to final network configuration with Tailscale.

## Table of Contents
1. [EC2 Instance Launch](#ec2-instance-launch)
2. [S3 Bucket File Download](#s3-bucket-file-download)
3. [File Format Conversion](#file-format-conversion)
4. [KVM Virtual Machine Creation](#kvm-virtual-machine-creation)
5. [DHCP Configuration](#dhcp-configuration)
6. [Tailscale Installation](#tailscale-installation)
7. [Troubleshooting](#troubleshooting)

---

## EC2 Instance Launch

### Instance Configuration
- **Instance Type**: c5.metal
- **Pricing Model**: Spot Instance
- **Operating System**: Linux (Ubuntu/Amazon Linux)
- **Storage**: EBS volumes as required

### Launch Steps
1. Navigate to EC2 Console
2. Select "Launch Instance"
3. Choose appropriate AMI (Ubuntu 20.04/22.04 LTS recommended)
4. Select `c5.metal` instance type
5. Configure spot instance pricing
6. Configure security groups:
   - SSH (port 22) from your IP
   - HTTP/HTTPS (ports 80/443) if needed
   - Custom ports for EVE-NG access
7. Launch with appropriate key pair

### Post-Launch Setup
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
sudo apt install -y awscli unzip p7zip-full
```

---

## S3 Bucket File Download

### Bucket Information
- **Bucket Name**: `ccie-bucket-08022025`
- **File Type**: .ova (Open Virtual Appliance)

### Download Process
```bash
# Configure AWS CLI (if not already configured)
aws configure

# Download .ova file from S3 bucket
aws s3 cp s3://ccie-bucket-08022025/<filename>.ova ./

# Verify download integrity
ls -la *.ova
```

### Alternative Download Methods
```bash
# Using wget if public access is available
wget https://ccie-bucket-08022025.s3.amazonaws.com/<filename>.ova

# Using curl
curl -O https://ccie-bucket-08022025.s3.amazonaws.com/<filename>.ova
```

---

## File Format Conversion

The conversion process involves multiple steps to transform the .ova file into a KVM-compatible qcow2 format.

### Step 1: Extract .ova to .vmdk
```bash
# Extract .ova file (it's essentially a tar archive)
tar -xvf <filename>.ova

# This will extract:
# - .ovf file (metadata)
# - .vmdk file (virtual disk)
# - .mf file (manifest)

# List extracted files
ls -la *.vmdk *.ovf *.mf
```

### Step 2: Convert .vmdk to .vdi
```bash
# Install VirtualBox tools for conversion
sudo apt install -y virtualbox

# Convert VMDK to VDI format
VBoxManage clonehd <filename>.vmdk <filename>.vdi --format VDI

# Verify conversion
ls -la *.vdi
```

### Step 3: Convert .vdi to .qcow2
```bash
# Convert VDI to QCOW2 format for KVM compatibility
qemu-img convert -f vdi -O qcow2 <filename>.vdi <filename>.qcow2

# Verify final conversion
qemu-img info <filename>.qcow2

# Check file sizes
ls -lh *.ova *.vmdk *.vdi *.qcow2
```

### Cleanup Intermediate Files
```bash
# Remove intermediate files to save space
rm <filename>.ova <filename>.vmdk <filename>.vdi <filename>.ovf <filename>.mf
```

---

## KVM Virtual Machine Creation

### Prerequisites
```bash
# Ensure KVM is properly installed and running
sudo systemctl status libvirtd
sudo systemctl enable libvirtd

# Add user to libvirt group
sudo usermod -a -G libvirt $USER
newgrp libvirt

# Verify KVM support
kvm-ok
```

### VM Creation
```bash
# Create VM using virt-install
sudo virt-install \
  --name eve-ng \
  --ram 8192 \
  --disk path=/var/lib/libvirt/images/<filename>.qcow2,format=qcow2 \
  --vcpus 4 \
  --os-type linux \
  --os-variant ubuntu20.04 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole \
  --import

# Alternative: Using virsh with XML definition
# Create VM XML configuration file first, then:
virsh define eve-ng.xml
virsh start eve-ng
```

### VM Management Commands
```bash
# List all VMs
virsh list --all

# Start VM
virsh start eve-ng

# Stop VM
virsh shutdown eve-ng

# Force stop VM
virsh destroy eve-ng

# Connect to VM console
virsh console eve-ng

# Get VM info
virsh dominfo eve-ng
```

---

## DHCP Configuration

### Enable DHCP on Default Network
```bash
# Check current network configuration
virsh net-list --all

# Edit default network to ensure DHCP is enabled
virsh net-edit default

# Ensure the network configuration includes DHCP range:
# <dhcp>
#   <range start='192.168.122.2' end='192.168.122.254'/>
# </dhcp>

# Restart the network
virsh net-destroy default
virsh net-start default

# Set network to autostart
virsh net-autostart default
```

### Verify DHCP Configuration
```bash
# Check network details
virsh net-dumpxml default

# Monitor DHCP leases
sudo cat /var/lib/libvirt/dnsmasq/virbr0.status

# Check bridge configuration
ip addr show virbr0
```

### VM Network Configuration
```bash
# Inside the VM, ensure network interface is configured for DHCP
# Edit /etc/netplan/01-netcfg.yaml (Ubuntu) or equivalent

network:
  version: 2
  ethernets:
    ens3:
      dhcp4: true

# Apply configuration
sudo netplan apply

# Verify IP assignment
ip addr show
```

---

## Tailscale Installation

### Why Tailscale?
Tailscale eliminates the need for complex port forwarding configurations by creating a secure mesh network, allowing direct access to your EVE-NG instance from anywhere.

### Installation on Host (EC2 Instance)
```bash
# Add Tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale
sudo apt update
sudo apt install tailscale

# Start Tailscale and authenticate
sudo tailscale up

# Follow the authentication URL provided
```

### Installation on VM (EVE-NG)
```bash
# SSH into the VM or use console
virsh console eve-ng

# Install Tailscale on the VM as well
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale on VM
sudo tailscale up

# Authenticate using the provided URL
```

### Tailscale Configuration
```bash
# Check Tailscale status
tailscale status

# Get Tailscale IP addresses
tailscale ip -4

# Enable subnet routing (if needed)
sudo tailscale up --advertise-routes=192.168.122.0/24

# Accept routes in Tailscale admin console
# Visit https://login.tailscale.com/admin/machines
```

### Access Configuration
```bash
# Now you can access EVE-NG directly via Tailscale IP
# Example: https://<tailscale-ip>/
# No need for complex port forwarding or security group modifications
```

---

## Troubleshooting

### Common Issues and Solutions

#### EC2 Spot Instance Interruption
```bash
# Monitor spot instance status
aws ec2 describe-spot-instance-requests

# Set up CloudWatch alarms for spot interruption warnings
aws cloudwatch put-metric-alarm --alarm-name "SpotInstanceInterruption" \
  --alarm-description "Alert on spot instance interruption" \
  --metric-name "SpotInstanceTerminating" \
  --namespace "AWS/EC2" \
  --statistic "Maximum" \
  --period 60 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold"
```

#### File Conversion Issues
```bash
# If conversion fails, check available disk space
df -h

# Verify file integrity
md5sum <filename>

# Check qemu-img version
qemu-img --version
```

#### KVM/Libvirt Issues
```bash
# Check libvirt logs
sudo journalctl -u libvirtd

# Verify KVM modules
lsmod | grep kvm

# Check VM logs
sudo cat /var/log/libvirt/qemu/eve-ng.log
```

#### Network Connectivity Issues
```bash
# Check bridge status
brctl show

# Verify iptables rules
sudo iptables -L -n

# Test connectivity from VM
ping 8.8.8.8

# Check DNS resolution
nslookup google.com
```

#### Tailscale Connection Issues
```bash
# Check Tailscale daemon status
sudo systemctl status tailscaled

# Restart Tailscale
sudo systemctl restart tailscaled

# Check Tailscale logs
sudo journalctl -u tailscaled

# Test connectivity
tailscale ping <other-device-ip>
```

---

## Security Considerations

### EC2 Security Groups
- Limit SSH access to your IP only
- Use Tailscale for secure remote access instead of opening ports publicly
- Regularly update security group rules

### VM Security
- Change default passwords immediately
- Keep the EVE-NG system updated
- Use strong authentication methods
- Implement proper backup strategies

### Tailscale Security
- Use device approval in Tailscale admin console
- Regularly review connected devices
- Enable key expiry for enhanced security
- Use ACLs to control access between devices

---

## Backup and Recovery

### VM Backup
```bash
# Create VM snapshot
virsh snapshot-create-as eve-ng snapshot1 "Pre-configuration snapshot"

# List snapshots
virsh snapshot-list eve-ng

# Restore from snapshot
virsh snapshot-revert eve-ng snapshot1
```

### Configuration Backup
```bash
# Backup VM configuration
virsh dumpxml eve-ng > eve-ng-config.xml

# Backup disk image
cp /var/lib/libvirt/images/<filename>.qcow2 /backup/location/
```

---

## Performance Optimization

### EC2 Instance Optimization
- Use placement groups for better network performance
- Enable SR-IOV for improved network performance
- Consider using NVMe SSD for better I/O performance

### KVM Optimization
```bash
# Enable virtio drivers for better performance
# Modify VM configuration to use virtio for disk and network

# CPU optimization
virsh edit eve-ng
# Add: <cpu mode='host-passthrough'/>
```

---

## Monitoring and Maintenance

### System Monitoring
```bash
# Monitor system resources
htop
iotop
nethogs

# Check VM resource usage
virsh domstats eve-ng
```

### Regular Maintenance
- Update system packages regularly
- Monitor disk space usage
- Review and rotate logs
- Update Tailscale client
- Review security group configurations

---

## Conclusion

This deployment provides a robust, scalable EVE-NG environment on AWS with secure remote access through Tailscale. The use of spot instances provides cost savings while the conversion process ensures compatibility with KVM virtualization.

For questions or issues, refer to the troubleshooting section or consult the official documentation for each component.

---

**Document Version**: 1.0  
**Last Updated**: August 3, 2025  
**Author**: Deployment Team
