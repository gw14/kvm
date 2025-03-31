# Creating a KVM Virtual Machine (VM)

Here's a step-by-step guide to creating a VM using KVM (Kernel-based Virtual Machine) on Linux:

## Prerequisites
1. A Linux system with CPU that supports virtualization (Intel VT-x or AMD-V)
2. KVM installed
3. Appropriate permissions (typically need to be root or in the libvirt group)

## Installation Steps

### 1. Verify Virtualization Support
```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```
If the output is 0, virtualization is not enabled in BIOS.

### 2. Install Required Packages
On Ubuntu/Debian:
```bash
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager
```

On RHEL/CentOS:
```bash
sudo yum install qemu-kvm libvirt libvirt-python libguestfs-tools virt-install virt-manager
```

### 3. Start and Enable libvirtd
```bash
sudo systemctl enable --now libvirtd
```

## Creating a VM

### Method 1: Using virt-install (CLI)
```bash
sudo virt-install \
  --name myvm \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/myvm.qcow2,size=20 \
  --os-type linux \
  --os-variant ubuntu20.04 \
  --network bridge=virbr0 \
  --graphics spice \
  --location 'http://archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/' \
  --extra-args 'console=ttyS0'
```

### Method 2: Using virt-manager (GUI)
1. Launch virt-manager: `virt-manager`
2. Click "Create a new virtual machine"
3. Follow the wizard to select installation media, configure resources, etc.

## Managing VMs

Common commands:
```bash
# List running VMs
virsh list

# List all VMs
virsh list --all

# Start a VM
virsh start myvm

# Shutdown a VM
virsh shutdown myvm

# Force stop a VM
virsh destroy myvm

# Delete a VM
virsh undefine myvm
```

## Networking Options
By default, VMs use NAT networking. For bridge networking:
1. Create a bridge interface
2. Use `--network bridge=br0` in virt-install

Would you like more detailed information about any specific part of this process?
