#!/bin/bash
set -euo pipefail

###############################################################################
# AWS Spot Instance Benchmark Script for p4d.24xlarge
#
# This script creates an AWS spot instance, runs the KVSP benchmark,
# fetches results, and terminates the instance.
#
# Usage:
#   ./aws_spot_benchmark.sh [options]
#
# Options:
#   -k, --key-name NAME       AWS key pair name (required)
#   -r, --region REGION       AWS region (default: us-east-1)
#   -p, --max-price PRICE     Max spot price in USD (default: auto)
#   -i, --ami AMI_ID          AMI ID (default: Deep Learning Base GPU AMI Ubuntu 24.04)
#   -s, --subnet SUBNET_ID    Subnet ID (optional, uses default VPC if not specified)
#   -g, --security-group SG   Security group ID (optional, creates one if not specified)
#   -n, --ngpus NUM           Number of GPUs to use (default: 8)
#   -o, --output-dir DIR      Local directory to store results (default: ./results_p4d)
#   -t, --instance-type TYPE  Instance type (default: p4d.24xlarge)
#   --keep-instance           Don't terminate instance after benchmark
#   --dry-run                 Show what would be done without executing
#   -h, --help                Show this help message
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - SSH key pair created in the target region
#   - Sufficient service quota for p4d instances
#
###############################################################################

# Default values
REGION="us-east-1"
INSTANCE_TYPE="p4d.24xlarge"
MAX_PRICE=""  # Empty means use on-demand price as max
KEY_NAME=""
AMI_ID=""
SUBNET_ID=""
SECURITY_GROUP_ID=""
NGPUS=8
KVSP_VER=34
OUTPUT_DIR="./results_p4d"
KEEP_INSTANCE=false
DRY_RUN=false
SSH_USER="ubuntu"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup tracking
INSTANCE_ID=""
CREATED_SG=""
SPOT_REQUEST_ID=""

###############################################################################
# Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_usage() {
    head -50 "$0" | grep -E "^#" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
}

cleanup() {
    local exit_code=$?
    log_info "Cleaning up..."

    if [[ -n "$SPOT_REQUEST_ID" ]]; then
        log_info "Cancelling spot request: $SPOT_REQUEST_ID"
        aws ec2 cancel-spot-instance-requests \
            --region "$REGION" \
            --spot-instance-request-ids "$SPOT_REQUEST_ID" 2>/dev/null || true
    fi

    if [[ -n "$INSTANCE_ID" && "$KEEP_INSTANCE" == "false" ]]; then
        log_info "Terminating instance: $INSTANCE_ID"
        aws ec2 terminate-instances \
            --region "$REGION" \
            --instance-ids "$INSTANCE_ID" 2>/dev/null || true
    fi

    if [[ -n "$CREATED_SG" ]]; then
        log_info "Waiting for instance termination before deleting security group..."
        sleep 30
        log_info "Deleting security group: $CREATED_SG"
        aws ec2 delete-security-group \
            --region "$REGION" \
            --group-id "$CREATED_SG" 2>/dev/null || true
    fi

    exit $exit_code
}

get_default_ami() {
    # Get AWS Deep Learning Base GPU AMI (Ubuntu 24.04)
    # This AMI comes with CUDA and NVIDIA drivers pre-installed, no reboot needed
    local ami
    ami=$(aws ec2 describe-images \
        --region "$REGION" \
        --owners amazon \
        --filters \
            "Name=name,Values=Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 24.04) ????????" \
            "Name=state,Values=available" \
        --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' \
        --output text 2>/dev/null)

    if [[ -z "$ami" || "$ami" == "None" ]]; then
        log_error "Could not find Deep Learning Base GPU AMI (Ubuntu 24.04)"
        log_error "Please specify an AMI ID with -i option"
        exit 1
    fi

    echo "$ami"
}

get_default_vpc() {
    aws ec2 describe-vpcs \
        --region "$REGION" \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text
}

get_default_subnet() {
    local vpc_id=$1
    aws ec2 describe-subnets \
        --region "$REGION" \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'Subnets[0].SubnetId' \
        --output text
}

create_security_group() {
    local vpc_id=$1
    local sg_name="kvsp-benchmark-sg-$(date +%Y%m%d%H%M%S)"

    log_info "Creating security group: $sg_name" >&2

    local sg_id
    sg_id=$(aws ec2 create-security-group \
        --region "$REGION" \
        --group-name "$sg_name" \
        --description "Security group for KVSP benchmark" \
        --vpc-id "$vpc_id" \
        --query 'GroupId' \
        --output text)

    # Allow SSH from anywhere (you may want to restrict this)
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$sg_id" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 >/dev/null

    echo "$sg_id"
}

get_spot_price() {
    # Get current spot price for the instance type
    aws ec2 describe-spot-price-history \
        --region "$REGION" \
        --instance-types "$INSTANCE_TYPE" \
        --product-descriptions "Linux/UNIX" \
        --start-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --query 'SpotPriceHistory[0].SpotPrice' \
        --output text 2>/dev/null || echo ""
}

wait_for_instance() {
    local instance_id=$1
    local max_wait=600  # 10 minutes
    local waited=0

    log_info "Waiting for instance $instance_id to be running..."

    while [[ $waited -lt $max_wait ]]; do
        local state
        state=$(aws ec2 describe-instances \
            --region "$REGION" \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text 2>/dev/null || echo "pending")

        if [[ "$state" == "running" ]]; then
            log_success "Instance is running"
            return 0
        elif [[ "$state" == "terminated" || "$state" == "shutting-down" ]]; then
            log_error "Instance was terminated"
            return 1
        fi

        echo -n "."
        sleep 10
        waited=$((waited + 10))
    done

    log_error "Timeout waiting for instance to start"
    return 1
}

wait_for_ssh() {
    local host=$1
    local key_file=$2
    local max_wait=300  # 5 minutes
    local waited=0

    log_info "Waiting for SSH to be available on $host..."

    while [[ $waited -lt $max_wait ]]; do
        if ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "echo 'SSH ready'" 2>/dev/null; then
            log_success "SSH is available"
            return 0
        fi

        echo -n "."
        sleep 10
        waited=$((waited + 10))
    done

    log_error "Timeout waiting for SSH"
    return 1
}

get_instance_ip() {
    local instance_id=$1
    aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text
}

run_remote_setup() {
    local host=$1
    local key_file=$2

    log_info "Setting up instance with required dependencies..."

    # Setup script for the remote instance
    # Deep Learning Base GPU AMI (Ubuntu 24.04) has NVIDIA drivers pre-installed
    local setup_script='#!/bin/bash
set -ex

# Verify NVIDIA drivers are available (should be pre-installed in Deep Learning AMI)
echo "Verifying NVIDIA drivers..."
nvidia-smi

# Install benchmark dependencies
sudo apt-get update
sudo apt-get install -y ruby ruby-dev libgoogle-perftools-dev libomp-dev build-essential libz3-dev git curl

# Install bundler
sudo gem install bundler -v 2.1.4 || sudo gem install bundler
sudo gem install websocket-driver -v 0.7.1 --source https://rubygems.org/ || true

# Clone or update benchmark repo
if [ -d "kvsp-benchmark" ]; then
    cd kvsp-benchmark
    git pull || true
else
    git clone https://github.com/virtualsecureplatform/kvsp-benchmark.git
    cd kvsp-benchmark
fi

# Install Ruby dependencies
bundle install

echo "Setup complete"
'

    ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "$setup_script"
}

check_nvidia_drivers() {
    local host=$1
    local key_file=$2

    log_info "Verifying NVIDIA drivers..."

    if ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "nvidia-smi" 2>/dev/null; then
        log_success "NVIDIA drivers are working"
        # Show GPU info
        ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "nvidia-smi --query-gpu=name,memory.total --format=csv"
        return 0
    else
        log_error "NVIDIA drivers not working. This is unexpected with Deep Learning AMI."
        log_error "Please check the AMI or instance type."
        return 1
    fi
}

run_benchmark() {
    local host=$1
    local key_file=$2
    local ngpus=$3
    local kvsp_ver=$4

    log_info "Running benchmark with $ngpus GPUs using KVSP v$kvsp_ver..."

    # Run benchmark with specified KVSP version
    local benchmark_script="#!/bin/bash
set -ex
cd kvsp-benchmark

# Download kvsp v$kvsp_ver if not exists
if [ ! -f \"kvsp_v${kvsp_ver}/bin/kvsp\" ]; then
    # Try new naming convention first (kvsp_vNN.tar.gz), then fall back to old (kvsp.tar.gz)
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v${kvsp_ver}/kvsp_v${kvsp_ver}.tar.gz | tar zx || \\
    curl -L https://github.com/virtualsecureplatform/kvsp/releases/download/v${kvsp_ver}/kvsp.tar.gz | tar zx
fi

# Download faststat if not exists
if [ ! -f faststat ]; then
    curl -o faststat -L https://github.com/ushitora-anqou/faststat/releases/download/v0.0.2/faststat
    chmod +x faststat
fi

# Make directory for results
results_dir=\$(date +'speed-%Y%m%d%H%M%S')
mkdir \$results_dir

# Run faststat
./faststat -t 0.1 \\
    time cpu.user cpu.nice cpu.sys cpu.idle cpu.iowait cpu.irq cpu.softirq \\
    cpu.steal mem.total mem.used mem.free mem.shared mem.buff_cache mem.available \\
    mem.swap.total mem.swap.used mem.swap.free nvml.temp nvml.power nvml.usage \\
    nvml.mem.used nvml.mem.free nvml.mem.total \\
    > \"\$results_dir/faststat.log\" &
FASTSTAT_PID=\$!

# Run benchmark.rb with KVSP v$kvsp_ver
bundle exec ruby benchmark.rb --kvsp-ver $kvsp_ver --output \"\$results_dir/benchmark_rb.log\" --pearl --cmux-memory -g $ngpus
bundle exec ruby benchmark.rb --kvsp-ver $kvsp_ver --output \"\$results_dir/benchmark_rb.log\" --ruby --cmux-memory -g $ngpus
bundle exec ruby benchmark.rb --kvsp-ver $kvsp_ver --output \"\$results_dir/benchmark_rb.log\" --pearl -g $ngpus
bundle exec ruby benchmark.rb --kvsp-ver $kvsp_ver --output \"\$results_dir/benchmark_rb.log\" --ruby -g $ngpus

# Stop faststat
kill \$FASTSTAT_PID || true

# Cleanup temp files
rm -f _* || true

echo \"Benchmark completed. Results in \$results_dir\"
"

    ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "$benchmark_script"

    log_success "Benchmark completed"
}

fetch_results() {
    local host=$1
    local key_file=$2
    local output_dir=$3

    log_info "Fetching benchmark results..."

    mkdir -p "$output_dir"

    # Find the latest results directory
    local results_dir
    results_dir=$(ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" \
        "ls -td kvsp-benchmark/speed-* 2>/dev/null | head -1" || echo "")

    if [[ -z "$results_dir" ]]; then
        log_error "No results directory found"
        return 1
    fi

    # Create a timestamped subdirectory
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local local_results_dir="$output_dir/p4d.24xlarge_${timestamp}"
    mkdir -p "$local_results_dir"

    # Copy all results
    scp $SSH_OPTIONS -i "$key_file" -r "$SSH_USER@$host:$results_dir/*" "$local_results_dir/"

    # Also get system info
    ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "nvidia-smi -q" > "$local_results_dir/nvidia_info.txt" 2>/dev/null || true
    ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "lscpu" > "$local_results_dir/cpu_info.txt" 2>/dev/null || true
    ssh $SSH_OPTIONS -i "$key_file" "$SSH_USER@$host" "free -h" > "$local_results_dir/memory_info.txt" 2>/dev/null || true

    log_success "Results saved to: $local_results_dir"
    echo "$local_results_dir"
}

###############################################################################
# Parse command line arguments
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--key-name)
            KEY_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -p|--max-price)
            MAX_PRICE="$2"
            shift 2
            ;;
        -i|--ami)
            AMI_ID="$2"
            shift 2
            ;;
        -s|--subnet)
            SUBNET_ID="$2"
            shift 2
            ;;
        -g|--security-group)
            SECURITY_GROUP_ID="$2"
            shift 2
            ;;
        -n|--ngpus)
            NGPUS="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --keep-instance)
            KEEP_INSTANCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

###############################################################################
# Validate inputs
###############################################################################

if [[ -z "$KEY_NAME" ]]; then
    log_error "Key name is required. Use -k or --key-name to specify."
    print_usage
    exit 1
fi

# Check if key file exists locally
KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"
if [[ ! -f "$KEY_FILE" ]]; then
    KEY_FILE="$HOME/.ssh/${KEY_NAME}"
fi
if [[ ! -f "$KEY_FILE" ]]; then
    log_error "SSH key file not found: $HOME/.ssh/${KEY_NAME}.pem or $HOME/.ssh/${KEY_NAME}"
    log_error "Please ensure your private key is in ~/.ssh/"
    exit 1
fi

# Check AWS CLI is available
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured. Please run 'aws configure'"
    exit 1
fi

###############################################################################
# Main execution
###############################################################################

# Set up cleanup trap
trap cleanup EXIT INT TERM

log_info "=============================================="
log_info "KVSP Benchmark on AWS Spot Instance"
log_info "=============================================="
log_info "Instance Type: $INSTANCE_TYPE"
log_info "Region: $REGION"
log_info "Number of GPUs: $NGPUS"
log_info "KVSP Version: $KVSP_VER"
log_info "Key Name: $KEY_NAME"
log_info "=============================================="

# Get AMI if not specified
if [[ -z "$AMI_ID" ]]; then
    log_info "Finding suitable AMI..."
    AMI_ID=$(get_default_ami)
    if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
        log_error "Could not find suitable AMI"
        exit 1
    fi
fi
log_info "Using AMI: $AMI_ID"

# Get VPC and subnet if not specified
if [[ -z "$SUBNET_ID" ]]; then
    log_info "Finding default VPC and subnet..."
    VPC_ID=$(get_default_vpc)
    if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
        log_error "No default VPC found. Please specify a subnet with -s"
        exit 1
    fi
    SUBNET_ID=$(get_default_subnet "$VPC_ID")
    log_info "Using VPC: $VPC_ID, Subnet: $SUBNET_ID"
else
    VPC_ID=$(aws ec2 describe-subnets \
        --region "$REGION" \
        --subnet-ids "$SUBNET_ID" \
        --query 'Subnets[0].VpcId' \
        --output text)
fi

# Create security group if not specified
if [[ -z "$SECURITY_GROUP_ID" ]]; then
    SECURITY_GROUP_ID=$(create_security_group "$VPC_ID")
    CREATED_SG="$SECURITY_GROUP_ID"
fi
log_info "Using Security Group: $SECURITY_GROUP_ID"

# Get current spot price for reference
CURRENT_SPOT_PRICE=$(get_spot_price)
if [[ -n "$CURRENT_SPOT_PRICE" ]]; then
    log_info "Current spot price: \$$CURRENT_SPOT_PRICE/hour"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run mode - would create spot instance with the above settings"
    exit 0
fi

# Request spot instance
log_info "Requesting spot instance..."

SPOT_REQUEST_JSON=$(cat <<EOF
{
    "ImageId": "$AMI_ID",
    "InstanceType": "$INSTANCE_TYPE",
    "KeyName": "$KEY_NAME",
    "SecurityGroupIds": ["$SECURITY_GROUP_ID"],
    "SubnetId": "$SUBNET_ID",
    "BlockDeviceMappings": [
        {
            "DeviceName": "/dev/sda1",
            "Ebs": {
                "VolumeSize": 100,
                "VolumeType": "gp3",
                "DeleteOnTermination": true
            }
        }
    ]
}
EOF
)

SPOT_OPTIONS="--instance-interruption-behavior terminate"
if [[ -n "$MAX_PRICE" ]]; then
    SPOT_OPTIONS="$SPOT_OPTIONS --spot-price $MAX_PRICE"
fi

SPOT_RESPONSE=$(aws ec2 request-spot-instances \
    --region "$REGION" \
    --instance-count 1 \
    --type "one-time" \
    $SPOT_OPTIONS \
    --launch-specification "$SPOT_REQUEST_JSON" \
    --output json)

SPOT_REQUEST_ID=$(echo "$SPOT_RESPONSE" | jq -r '.SpotInstanceRequests[0].SpotInstanceRequestId')
log_info "Spot request ID: $SPOT_REQUEST_ID"

# Wait for spot request to be fulfilled
log_info "Waiting for spot request to be fulfilled..."
MAX_SPOT_WAIT=600
SPOT_WAITED=0

while [[ $SPOT_WAITED -lt $MAX_SPOT_WAIT ]]; do
    SPOT_STATUS=$(aws ec2 describe-spot-instance-requests \
        --region "$REGION" \
        --spot-instance-request-ids "$SPOT_REQUEST_ID" \
        --query 'SpotInstanceRequests[0].Status.Code' \
        --output text)

    INSTANCE_ID=$(aws ec2 describe-spot-instance-requests \
        --region "$REGION" \
        --spot-instance-request-ids "$SPOT_REQUEST_ID" \
        --query 'SpotInstanceRequests[0].InstanceId' \
        --output text)

    if [[ "$SPOT_STATUS" == "fulfilled" && "$INSTANCE_ID" != "None" && -n "$INSTANCE_ID" ]]; then
        log_success "Spot request fulfilled, Instance ID: $INSTANCE_ID"
        break
    elif [[ "$SPOT_STATUS" == "price-too-low" ]]; then
        log_error "Spot price too low. Current price: $CURRENT_SPOT_PRICE"
        exit 1
    elif [[ "$SPOT_STATUS" == "capacity-not-available" ]]; then
        log_error "No capacity available for $INSTANCE_TYPE in $REGION"
        exit 1
    fi

    echo -n "."
    sleep 10
    SPOT_WAITED=$((SPOT_WAITED + 10))
done

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
    log_error "Failed to get instance from spot request"
    exit 1
fi

# Tag the instance
aws ec2 create-tags \
    --region "$REGION" \
    --resources "$INSTANCE_ID" \
    --tags Key=Name,Value="kvsp-benchmark-$(date +%Y%m%d%H%M%S)"

# Wait for instance to be running
wait_for_instance "$INSTANCE_ID"

# Get public IP
PUBLIC_IP=$(get_instance_ip "$INSTANCE_ID")
log_info "Instance public IP: $PUBLIC_IP"

# Wait for SSH
wait_for_ssh "$PUBLIC_IP" "$KEY_FILE"

# Setup instance
run_remote_setup "$PUBLIC_IP" "$KEY_FILE"

# Check NVIDIA drivers
check_nvidia_drivers "$PUBLIC_IP" "$KEY_FILE"

# Run benchmark
run_benchmark "$PUBLIC_IP" "$KEY_FILE" "$NGPUS" "$KVSP_VER"

# Fetch results
RESULTS_DIR=$(fetch_results "$PUBLIC_IP" "$KEY_FILE" "$OUTPUT_DIR")

log_info "=============================================="
log_success "Benchmark completed successfully!"
log_info "Results saved to: $RESULTS_DIR"
log_info "=============================================="

if [[ "$KEEP_INSTANCE" == "true" ]]; then
    log_info "Instance kept running: $INSTANCE_ID ($PUBLIC_IP)"
    log_info "To terminate later: aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
    # Clear variables so cleanup doesn't terminate
    INSTANCE_ID=""
    CREATED_SG=""
fi
