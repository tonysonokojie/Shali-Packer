#!/bin/bash

set -e

# Example of critical standards script 001
echo "Running 001-critical-standards.sh..." | tee /tmp/001-critical-standards.log

if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root. Exiting..."
    exit 1
fi

# Function to configure secure boot settings
configure_secure_boot() {
    echo "Configuring secure boot settings..."

    if [ -d /sys/firmware/efi ]; then
        echo "System is UEFI-based, secure boot can be configured."
        if [ -f /etc/debian_version ]; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y mokutil
            mokutil --sb-state
        elif [ -f /etc/redhat-release ]; then
            yum install -y mokutil
            mokutil --sb-state
        else
            echo "Unsupported OS. Exiting..."
            exit 1
        fi
    else
        echo "System is not UEFI-based, secure boot settings are not applicable."
    fi
}

# Function to fix GPG error and configure repositories
fix_gpg_error() {
    echo "Fixing GPG error and configuring repositories..."

    if [ -f /etc/debian_version ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update --allow-unauthenticated
        apt-get install -y gnupg
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
        apt-get update
    elif [ -f /etc/redhat-release ]; then
        yum install -y epel-release
        rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
    else
        echo "Unsupported OS. Exiting..."
        exit 1
    fi
}

# Function to implement file integrity monitoring
implement_fim() {
    echo "Implementing file integrity monitoring..."

    if [ -f /etc/debian_version ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y aide
        aideinit
        cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    elif [ -f /etc/redhat-release ]; then
        yum install -y aide
        aide --init
        cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    else
        echo "Unsupported OS. Exiting..."
        exit 1
    fi

    echo "File integrity monitoring configured."
}

# Function to enforce minimum password length
enforce_password_length() {
    if [ -f /etc/debian_version ]; then
        sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN   12/' /etc/login.defs
    elif [ -f /etc/redhat-release ]; then
        sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN   12/' /etc/login.defs
    fi
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Failed to enforce minimum password length. Exiting..."
        exit 1
    fi
    return $exit_code
}

# Function to enforce account lockout
enforce_account_lockout() {
    if [ -f /etc/debian_version ]; then
        echo "auth required pam_tally2.so deny=5 unlock_time=900" >> /etc/pam.d/common-auth
    elif [ -f /etc/redhat-release ]; then
        echo "auth required pam_tally2.so deny=5 unlock_time=900" >> /etc/pam.d/system-auth
    fi
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Failed to enforce account lockout policy. Exiting..."
        exit 1
    fi
    return $exit_code
}

# Function to configure secure SSH settings
configure_ssh() {
    echo "Configuring secure SSH settings..."

    sshd_config="/etc/ssh/sshd_config"

    if [ -f "$sshd_config" ]; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$sshd_config"
        sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
        echo "AllowUsers ubuntu" >> "$sshd_config"
        systemctl restart sshd
    else
        echo "SSHD config file not found. Exiting..."
        exit 1
    fi

    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Failed to configure SSH settings. Exiting..."
        exit 1
    fi

    echo "SSH settings configured successfully."
    return $exit_code
}

# Function to configure the firewall
configure_firewall() {
    echo "Configuring firewall..."

    if [ -f /etc/debian_version ]; then
        apt-get install -y ufw

        commands=(
            "ufw default deny incoming"
            "ufw default allow outgoing"
            "ufw allow ssh"
            "ufw allow http"
            "ufw allow https"
            "ufw enable"
        )

        for cmd in "${commands[@]}"; do
            echo "Executing: $cmd"
            if ! $cmd; then
                echo "Error executing: $cmd"
                exit 1
            fi
        done

    elif [ -f /etc/redhat-release ]; then
        yum install -y firewalld
        systemctl start firewalld
        systemctl enable firewalld

        commands=(
            "firewall-cmd --default-zone=public --permanent"
            "firewall-cmd --zone=public --add-service=ssh"
            "firewall-cmd --zone=public --add-service=http"
            "firewall-cmd --zone=public --add-service=https"
            "firewall-cmd --reload"
        )

        for cmd in "${commands[@]}"; do
            echo "Executing: $cmd"
            if ! $cmd; then
                echo "Error executing: $cmd"
                exit 1
            fi
        done

    else
        echo "Unsupported OS. Exiting..."
        exit 1
    fi

    echo "Firewall configured successfully."
}

# Function to enable Logging and Audit
enable_logging_auditing() {

  sysCalls=( bind connect execve fork open read write listen)
    # Install and configure auditd
    if [ -f /etc/debian_version ]; then
        apt-get install auditd -y
    elif [ -f /etc/redhat-release ]; then
        yum install audit -y
    else
        echo "Unsupported operating system" >&2
        return 1
    fi
     # Enable and start auditd service
        systemctl enable auditd && systemctl start auditd
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start auditd" >&2
        return 1
    fi

        # Validate auditctl is available
    if ! command -v auditctl &> /dev/null; then
        echo "Error: auditctl command not found" >&2
        return 1
    fi
    # Add audit rules for specific system calls
    for sysCall in "${sysCalls[@]}"; do
      auditctl -a exit,always -F arch=b64 -S "$sysCall"
    done

    if [ $? -ne 0 ]; then
        echo "Error: Failed to configure auditctl for failed system calls" >&2
        return 1
    fi

    return 0
}

# Function to limit user privileges
limit_user_privileges() {
  authorized_user=$1
  # Configure sudoers file to limit root access
    echo "$authorized_user"
    echo "$authorized_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/authorized_user
  # Set proper permissions for the sudoers file
    chmod 0440 /etc/sudoers.d/authorized_user
  # Ensure only authorized users have sudo access
    usermod -aG sudo "$authorized_user"
  # Validate sudo configuration
    visudo -c

    exit_code=$?
    return $exit_code
}

# Call the functions
enable_logging_auditing
fix_gpg_error
configure_secure_boot
implement_fim
enforce_password_length
enforce_account_lockout
limit_user_privileges "${1}"
configure_ssh
configure_firewall

echo "001-critical-standards.sh completed successfully."
