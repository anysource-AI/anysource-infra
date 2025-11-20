#!/bin/bash

# Runlayer ToolGuard GPU Instance User Data Script
# This script configures g6f.large instances for ECS with NVIDIA GRID drivers
# GRID drivers are installed at runtime for worldwide deployment simplicity
# Using Ubuntu 22.04 to match the original manual build environment

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Logging setup
exec 1> >(logger -s -t $(basename $0)) 2>&1

echo "========================================="
echo "Runlayer ToolGuard GPU Instance Setup"
echo "Installing NVIDIA GRID drivers at runtime"
echo "Platform: Ubuntu 22.04"
echo "========================================="

# Update system
echo "==> Updating system packages..."
apt-get update -y || { echo "Failed to update package lists"; exit 1; }
apt-get upgrade -y || { echo "Failed to upgrade system packages"; exit 1; }

# Install kernel headers and development tools (required for GRID driver)
echo "==> Installing kernel headers and build tools..."
apt-get install -y build-essential dkms linux-headers-$(uname -r) ca-certificates curl unzip || {
  echo "Failed to install kernel development packages"
  exit 1
}

# Install AWS CLI (required for downloading GRID drivers from S3)
echo "==> Installing AWS CLI..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || {
  echo "Failed to download AWS CLI"
  exit 1
}
unzip -q awscliv2.zip || {
  echo "Failed to unzip AWS CLI"
  exit 1
}
./aws/install || {
  echo "Failed to install AWS CLI"
  exit 1
}
rm -rf awscliv2.zip aws
echo "✅ AWS CLI installed successfully"

# Download and install NVIDIA GRID drivers
echo "==> Downloading NVIDIA GRID driver from AWS S3..."
cd /tmp
/usr/local/bin/aws s3 cp s3://ec2-linux-nvidia-drivers/latest/NVIDIA-Linux-x86_64-580.95.05-grid-aws.run . \
  --region ${region} --no-sign-request || {
  echo "Failed to download GRID driver"
  exit 1
}

echo "==> Installing NVIDIA GRID driver..."
chmod +x NVIDIA-Linux-x86_64-580.95.05-grid-aws.run
./NVIDIA-Linux-x86_64-580.95.05-grid-aws.run --silent --install-libglvnd --dkms || {
  echo "Failed to install GRID driver"
  exit 1
}

# Verify GPU driver installation
echo "==> Verifying NVIDIA driver installation..."
if ! nvidia-smi; then
  echo "ERROR: nvidia-smi failed - GPU driver not working"
  exit 1
fi

echo "✅ NVIDIA GRID driver installed successfully"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

# Install Docker (based on your exact steps from history)
echo "==> Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg || {
  echo "Failed to add Docker GPG key"
  exit 1
}
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io || {
  echo "Failed to install Docker"
  exit 1
}

# Enable and start Docker
systemctl enable docker
systemctl start docker || { echo "Failed to start Docker"; exit 1; }

# Install NVIDIA Container Toolkit (based on your exact steps)
echo "==> Installing NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg || {
  echo "Failed to add NVIDIA Container Toolkit GPG key"
  exit 1
}

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list || {
  echo "Failed to add NVIDIA Container Toolkit repository"
  exit 1
}

apt-get update -y
apt-get install -y nvidia-container-toolkit || {
  echo "Failed to install NVIDIA Container Toolkit"
  exit 1
}

# Configure Docker to use NVIDIA runtime
echo "==> Configuring Docker for NVIDIA GPU access..."
nvidia-ctk runtime configure --runtime=docker || {
  echo "Failed to configure NVIDIA runtime for Docker"
  exit 1
}

# Restart Docker to apply configuration
systemctl restart docker || {
  echo "Failed to restart Docker"
  exit 1
}

# Test GPU access from Docker
echo "==> Testing GPU access from Docker containers..."
if docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi > /dev/null 2>&1; then
  echo "✅ GPU is accessible from Docker containers"
else
  echo "WARNING: GPU Docker test failed, but continuing..."
fi

# Configure ECS agent
echo "==> Configuring ECS agent for GPU support..."
mkdir -p /etc/ecs
cat <<EOF > /etc/ecs/ecs.config
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_GPU_SUPPORT=true
ECS_ENABLE_CONTAINER_METADATA=true
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_LOGFILE=/log/ecs-agent.log
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
ECS_LOGLEVEL=info
EOF

if [ ! -f /etc/ecs/ecs.config ]; then
  echo "Failed to create ECS configuration file"
  exit 1
fi

# Install CloudWatch agent for monitoring
echo "==> Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb || {
  echo "Failed to download CloudWatch agent"
  exit 1
}
dpkg -i /tmp/amazon-cloudwatch-agent.deb || {
  echo "Failed to install CloudWatch agent"
  exit 1
}
rm -f /tmp/amazon-cloudwatch-agent.deb

# Configure CloudWatch agent for GPU monitoring
echo "Configuring CloudWatch agent..."
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "AWS/ECS/RunlayerToolGuard",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/ecs/ecs-agent.log",
            "log_group_name": "anysource-runlayer-tool-guard-logs-${environment}",
            "log_stream_name": "{instance_id}/ecs-agent"
          },
          {
            "file_path": "/var/log/docker",
            "log_group_name": "anysource-runlayer-tool-guard-logs-${environment}",
            "log_stream_name": "{instance_id}/docker"
          }
        ]
      }
    }
  }
}
EOF

# Validate CloudWatch configuration
if [ ! -f /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json ]; then
  echo "Failed to create CloudWatch configuration file"
  exit 1
fi

# Start CloudWatch agent
echo "Starting CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s || { echo "Warning: CloudWatch agent failed to start, but continuing..."; }

# Install and start ECS agent (Ubuntu doesn't have it pre-installed)
echo "==> Installing ECS agent..."
curl -o /tmp/ecs-init.deb https://s3.amazonaws.com/amazon-ecs-agent-${region}/amazon-ecs-init-latest.amd64.deb || {
  echo "Failed to download ECS agent"
  exit 1
}
dpkg -i /tmp/ecs-init.deb || {
  echo "Failed to install ECS agent"
  exit 1
}
rm -f /tmp/ecs-init.deb

# Start ECS agent to pick up GPU configuration
echo "==> Starting ECS agent..."
systemctl enable ecs
systemctl start ecs || { echo "Failed to start ECS agent"; exit 1; }

# Wait for ECS agent to register and verify it's running
echo "==> Waiting for ECS agent to start..."
for i in {1..30}; do
  if systemctl is-active --quiet ecs; then
    echo "✅ ECS agent is running"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "ERROR: ECS agent failed to start after 30 seconds"
    exit 1
  fi
  sleep 1
done

# Cleanup temporary files
echo "==> Cleaning up..."
rm -f /tmp/NVIDIA-Linux-x86_64-*.run

# Additional wait for ECS registration
sleep 30

echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo "GPU Information:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
echo ""
echo "ECS Cluster: ${cluster_name}"
echo "GPU Support: Enabled"
echo "Docker GPU Access: Configured"
echo "========================================="
