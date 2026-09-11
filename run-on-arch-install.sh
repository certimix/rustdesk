#!/bin/bash
set -e

echo "Starting Ubuntu 18.04 package installation with retry logic..."

# Configure apt retry policy
cat > /etc/apt/apt.conf.d/99retry-config <<EOF
APT::Retries "5";
APT::Acquire::Retries "5";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::http::Timeout "60";
Acquire::https::Timeout "60";
EOF

# Function to retry apt operations
apt_retry() {
    local max_attempts=5
    local attempt=1
    local cmd="$@"
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Running: $cmd"
        if eval "$cmd"; then
            return 0
        fi
        echo "Attempt $attempt failed. Retrying in 10 seconds..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "Command failed after $max_attempts attempts: $cmd"
    return 1
}

# Update package cache with retries
echo "Updating package cache..."
apt_retry "apt-get update"

# Install essential build tools (split into groups for better resilience)
echo "Installing base build tools..."
apt_retry "apt-get install --fix-missing -y \
    build-essential \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    software-properties-common"

echo "Installing assembly and compilation tools..."
apt_retry "apt-get install --fix-missing -y \
    nasm \
    yasm \
    clang \
    make \
    cmake \
    pkg-config"

echo "Installing GUI development libraries..."
apt_retry "apt-get install --fix-missing -y \
    libgtk-3-dev \
    libxcb-randr0-dev \
    libxdo-dev \
    libxfixes-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev"

echo "Installing audio libraries..."
apt_retry "apt-get install --fix-missing -y \
    libasound2-dev \
    libpulse-dev"

echo "Installing SSL and compression libraries..."
apt_retry "apt-get install --fix-missing -y \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev"

echo "Installing misc utilities..."
apt_retry "apt-get install --fix-missing -y \
    unzip \
    zip \
    sudo \
    ninja-build"

# Install GStreamer with fallback for network issues
echo "Installing GStreamer libraries..."
apt_retry "apt-get install --fix-missing -y gstreamer1.0-plugins-base" || \
apt_retry "apt-get install --fix-missing -y libgstreamer1.0-dev" || \
echo "Warning: Some GStreamer packages could not be installed (network issue or not critical)"

# Clean up apt cache to save space
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Package installation completed successfully!"
