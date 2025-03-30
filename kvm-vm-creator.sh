#!/bin/bash

# KVM VM Creation Script with Logging and Dry-Run
# Version: 1.2
# Usage: sudo ./kvm-vm-creator.sh [OPTIONS]

# --------------------------
# Configuration
# --------------------------

LOG_FILE="/var/log/kvm-vm-creator.log"
DRY_RUN=false

# --------------------------
# Function Definitions
# --------------------------

log() {
    local timestamp=$(date +"%Y-%m-%d %T")
    local level=$1
    local message=$2
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

show_help() {
    cat << EOF
KVM Virtual Machine Creator

Usage: sudo $0 [OPTIONS]

Options:
  -h, --help          Show this help message and exit
  -n, --name NAME     Set VM name (required)
  -r, --ram RAM       Set RAM in MB (default: 2048)
  -c, --cpus CPUS     Set number of vCPUs (default: 2)
  -d, --disk DISK     Set disk size in GB (default: 20)
  -o, --os OS_TYPE    Set OS variant (e.g. 'ubuntu20.04', 'centos7.0')
  -i, --iso ISO_PATH  Set ISO file path (alternative to --url)
  -u, --url URL       Set installation URL (alternative to --iso)
  -b, --bridge BRIDGE Set bridge interface name (default: NAT)
  -a, --auto          Run in non-interactive mode (requires all parameters)
  --dry-run           Show what would be executed without making changes

Examples:
  # Dry-run with minimal parameters
  sudo $0 --name testvm --ram 2048 --cpus 2 --disk 20 --os ubuntu20.04 --dry-run
  
  # Automated creation with bridge networking
  sudo $0 -n prodvm -r 4096 -c 4 -d 40 -o centos7.0 -u http://mirror.centos.org/centos/7/os/x86_64/ -b br0
EOF
}

init_logging() {
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    log "INFO" "Script started"
    log "INFO" "Logging initialized at $LOG_FILE"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "This script must be run as root or with sudo"
        show_help
        exit 1
    fi
}

check_virtualization() {
    log "INFO" "Checking virtualization support"
    if ! egrep -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        log "ERROR" "CPU virtualization extensions not found. Enable VT-x/AMD-V in BIOS."
        exit 1
    fi
}

install_kvm() {
    if ! command -v virsh &> /dev/null; then
        log "WARN" "KVM/libvirt not found. Attempting installation..."
        
        if $DRY_RUN; then
            log "DRYRUN" "Would install KVM packages"
            return
        fi

        if [ -f /etc/redhat-release ]; then
            yum install -y qemu-kvm libvirt libvirt-python libguestfs-tools virt-install
        elif [ -f /etc/debian_version ]; then
            apt update && apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst
        else
            log "ERROR" "Unsupported OS. Please install KVM manually."
            exit 1
        fi
        systemctl enable --now libvirtd
        log "INFO" "KVM installation completed"
    fi
}

validate_inputs() {
    log "INFO" "Validating inputs"
    
    if [ -z "$VM_NAME" ]; then
        log "ERROR" "VM name is required"
        show_help
        exit 1
    fi
    
    # Set defaults if not provided
    VM_RAM=${VM_RAM:-2048}
    VM_CPUS=${VM_CPUS:-2}
    VM_DISK=${VM_DISK:-20}
    
    DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
    
    log "DEBUG" "Validated inputs: Name=$VM_NAME, RAM=$VM_RAM, CPUs=$VM_CPUS, Disk=$VM_DISK"
}

get_interactive_input() {
    log "INFO" "Starting interactive input collection"
    
    echo "=== KVM VM Creation ==="
    read -p "Enter VM name (required): " VM_NAME
    read -p "Enter RAM in MB [${VM_RAM}]: " input
    VM_RAM=${input:-$VM_RAM}
    read -p "Enter number of vCPUs [${VM_CPUS}]: " input
    VM_CPUS=${input:-$VM_CPUS}
    read -p "Enter disk size in GB [${VM_DISK}]: " input
    VM_DISK=${input:-$VM_DISK}
    read -p "Enter OS variant (e.g. ubuntu20.04, centos7.0): " OS_VARIANT
    
    # Installation method
    echo -e "\nInstallation Method:"
    echo "1) ISO file"
    echo "2) Network installation"
    read -p "Enter choice [1]: " INSTALL_METHOD
    INSTALL_METHOD=${INSTALL_METHOD:-1}
    
    if [ "$INSTALL_METHOD" == "1" ]; then
        read -p "Enter full path to ISO file: " ISO_PATH
        if [ ! -f "$ISO_PATH" ]; then
            log "ERROR" "ISO file not found: $ISO_PATH"
            exit 1
        fi
        INSTALL_SOURCE="--cdrom $ISO_PATH"
        log "DEBUG" "Using ISO source: $ISO_PATH"
    else
        read -p "Enter installation URL: " INSTALL_URL
        INSTALL_SOURCE="--location $INSTALL_URL"
        log "DEBUG" "Using network source: $INSTALL_URL"
    fi
    
    # Network configuration
    echo -e "\nNetwork Configuration:"
    echo "1) NAT (default)"
    echo "2) Bridge"
    read -p "Enter choice [1]: " NET_CHOICE
    NET_CHOICE=${NET_CHOICE:-1}
    
    if [ "$NET_CHOICE" == "2" ]; then
        read -p "Enter bridge interface name (e.g. br0): " BRIDGE_NAME
        NET_CONFIG="--network bridge=${BRIDGE_NAME}"
        log "DEBUG" "Using bridge networking: $BRIDGE_NAME"
    else
        NET_CONFIG="--network network=default"
        log "DEBUG" "Using default NAT networking"
    fi
}

create_vm() {
    log "INFO" "Preparing to create VM: $VM_NAME"
    
    local command="virt-install \
        --name ${VM_NAME} \
        --ram ${VM_RAM} \
        --vcpus ${VM_CPUS} \
        --disk path=${DISK_PATH},size=${VM_DISK} \
        --os-variant ${OS_VARIANT} \
        ${INSTALL_SOURCE} \
        ${NET_CONFIG} \
        --graphics spice \
        --console pty,target_type=serial \
        --noautoconsole"
    
    log "DEBUG" "Full command: $command"
    
    if $DRY_RUN; then
        log "DRYRUN" "Would execute: $command"
        log "DRYRUN" "VM creation skipped (dry-run mode)"
        return
    fi

    log "INFO" "Creating VM now..."
    eval $command
    
    if [ $? -eq 0 ]; then
        log "INFO" "VM creation command executed successfully"
    else
        log "ERROR" "VM creation failed with exit code $?"
        exit 1
    fi
}

show_completion() {
    local message="\nVM creation process completed"
    if $DRY_RUN; then
        message+=" (dry-run)"
    fi
    
    echo -e "$message"
    log "INFO" "Script completed successfully"
    
    echo -e "\nManagement commands:"
    echo "  Start VM:    virsh start ${VM_NAME}"
    echo "  Connect:     virsh console ${VM_NAME}"
    echo "  Shutdown:    virsh shutdown ${VM_NAME}"
    echo "  Destroy:     virsh destroy ${VM_NAME}"
    echo "  Autostart:   virsh autostart ${VM_NAME}"
    echo -e "\nView all VMs: virsh list --all"
}

# --------------------------
# Main Execution
# --------------------------

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--name)
            VM_NAME="$2"
            shift 2
            ;;
        -r|--ram)
            VM_RAM="$2"
            shift 2
            ;;
        -c|--cpus)
            VM_CPUS="$2"
            shift 2
            ;;
        -d|--disk)
            VM_DISK="$2"
            shift 2
            ;;
        -o|--os)
            OS_VARIANT="$2"
            shift 2
            ;;
        -i|--iso)
            ISO_PATH="$2"
            INSTALL_SOURCE="--cdrom $ISO_PATH"
            shift 2
            ;;
        -u|--url)
            INSTALL_URL="$2"
            INSTALL_SOURCE="--location $INSTALL_URL"
            shift 2
            ;;
        -b|--bridge)
            BRIDGE_NAME="$2"
            NET_CONFIG="--network bridge=${BRIDGE_NAME}"
            shift 2
            ;;
        -a|--auto)
            AUTO_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

main() {
    init_logging
    check_root
    check_virtualization
    install_kvm
    
    if [ "$AUTO_MODE" = true ] || [ "$DRY_RUN" = true ]; then
        validate_inputs
    else
        get_interactive_input
    fi
    
    create_vm
    show_completion
}

main
