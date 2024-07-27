#!/bin/bash

set -e

# Example of critical standards script 002
echo "Running 002-critical-standards.sh..." | tee /tmp/002-critical-standards.log

if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root. Exiting..."
    exit 1
fi

# Function to enforce password expiry policy
enforce_password_expiry() {
    echo "Enforcing password expiry policy..."

    # For Debian-based systems
    if [ -f /etc/debian_version ]; then
        # Install libpam-pwquality if not already installed
        apt-get update && apt-get install -y libpam-pwquality
        echo "PASS_MAX_DAYS 90" >> /etc/login.defs
        echo "PASS_MIN_DAYS 10" >> /etc/login.defs
        echo "PASS_WARN_AGE 7" >> /etc/login.defs
        for user in $(awk -F: '{if ($3 >= 1000) print $1}' /etc/passwd); do
            chage --maxdays 90 --mindays 10 --warndays 7 $user
        done
    # For RedHat-based systems
    elif [ -f /etc/redhat-release ]; then
        # Install libpwquality if not already installed
        yum install -y libpwquality
        echo "PASS_MAX_DAYS 90" >> /etc/login.defs
        echo "PASS_MIN_DAYS 10" >> /etc/login.defs
        echo "PASS_WARN_AGE 7" >> /etc/login.defs
        for user in $(awk -F: '{if ($3 >= 1000) print $1}' /etc/passwd); do
            chage --maxdays 90 --mindays 10 --warndays 7 $user
        done
    else
        echo "Failed to enforce password expiry policy. Exiting..."
        exit 1
    fi

    echo "Password expiry policy enforced."
}

# Function to disable USB ports
disable_usb_ports() {
    echo "Disabling USB ports..."

    # Create a blacklist file to disable USB storage
    echo "blacklist usb-storage" > /etc/modprobe.d/disable-usb-storage.conf

    # For Debian-based systems
    if [ -f /etc/debian_version ]; then
        update-initramfs -u
    # For RedHat-based systems
    elif [ -f /etc/redhat-release ]; then
        dracut -f
    else
        echo "Failed to disable USB ports. Exiting..."
        exit 1
    fi

    echo "USB ports disabled."
}

# Function to configure time synchronization
configure_time_sync() {
    echo "Configuring time synchronization..."
    if [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y chrony
        systemctl enable chrony && systemctl restart chrony
    elif [ -f /etc/redhat-release ]; then
        yum install -y chrony
        systemctl enable chronyd && systemctl restart chronyd
    else
        echo "Unsupported OS. Exiting..."
        exit 1
    fi
    echo "Time synchronization configured."
}

# Function to secure kernel parameters
secure_kernel_params() {
    echo "Securing kernel parameters..."
    sysctl_conf='/etc/sysctl.conf'
    commands=(
        "net.ipv4.ip_forward=0"
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.all.secure_redirects=0"
        "net.ipv4.conf.all.log_martians=1"
        "kernel.randomize_va_space=2"
    )
    for command in "${commands[@]}"; do
        if ! grep -q "^$command" "$sysctl_conf"; then
            echo "$command" >> "$sysctl_conf"
        fi
    done
    sysctl -p
    echo "Kernel parameters secured."
}

# Function to Update DNS settings to use AWS-provided DNS servers

configure_secure_dns() {
    AWS_DNS_SERVER="169.254.169.253"
    if [ -f /etc/debian_version ]; then
        # echo "nameserver $AWS_DNS_SERVER" >> /etc/resolv.conf | sudo tee /etc/resolv.conf
        echo "nameserver $AWS_DNS_SERVER" | tee /etc/resolv.conf
        echo "supersede domain-name-servers $AWS_DNS_SERVER" | tee -a /etc/dhcp/dhclient.conf
        systemctl restart systemd-networkd
    elif [ -f /etc/redhat-release ]; then
        echo "nameserver $AWS_DNS_SERVER" | tee /etc/resolv.conf
        echo "supersede domain-name-servers $AWS_DNS_SERVER" | tee -a /etc/dhcp/dhclient.conf
        systemctl restart NetworkManager
    fi
    chmod 644 /etc/resolv.conf
    nslookup amazon.com
    exit_code=$?
    return $exit_code
}

# Function to remove unnecessary packages
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="$script_dir/Packages_To_Delete.csv"

remove_unnecessary_packages() {
DEBIAN_CRITICAL_SERVICES=("sshd" "systemd-networkd" "chrony" "git" "cron" "systemd-journald" "firewalld")
REDHAT_CRITICAL_SERVICES=("sshd" "NetworkManager" "selinux" "cron" "systemd-journald" "firewalld" "ssh")
# Check if the CSV file exist
    if [[ ! -f "$CSV_FILE" ]]; then
        echo "CSV file not found: $CSV_FILE"
        exit 1
    fi
# Determine the Package Manager and set the appropriate command
    if [[ -f /etc/debian_version ]]; then
        LIST_PACKAGES_CMD="dpkg --list"
        PACKAGE_MANAGER="Debian"
        REMOVE_CMD="apt-get remove -y"
        CRITICAL_SERVICES="$DEBIAN_CRITICAL_SERVICES"
    elif [[ -f /etc/redhat-release ]]; then
        LIST_PACKAGES_CMD="rpm -qa"
        PACKAGE_MANAGER="Red Hat"
        REMOVE_CMD="yum remove -y"
        CRITICAL_SERVICES="$REDHAT_CRITICAL_SERVICES"
    else
        echo "Unsupported system type"
        exit 1
    fi
    # List all installed packages
    echo "Listing all installed packages:"
    $LIST_PACKAGES_CMD
    package_found=false
# Remove the first line and overwrite the original file
    tail -n +2 "$CSV_FILE" > tmpfile.csv && mv tmpfile.csv "$CSV_FILE"
# Read new CSV file and process each line
    while IFS=',' read -r debian_pkg redhat_pkg
    do
        if [[ "$PACKAGE_MANAGER" == "Debian" && -n "$debian_pkg" ]]; then
            echo "Deleting Debian packages: $debian_pkg"
            $REMOVE_CMD $debian_pkg
            package_found=true
        elif [[ "$PACKAGE_MANAGER" == "Red Hat" && -n "$redhat_pkg" ]]; then
            echo "Deleting Red-Hat packages: $redhat_pkg"
            $REMOVE_CMD $redhat_pkg
            package_found=true
        fi
    done < "$CSV_FILE"
    # Check if any packages were found and deleted
    if [[ "$package_found" == false ]]; then
        echo "No packages to delete for $PACKAGE_MANAGER"
    fi

    for service in "${CRITICAL_SERVICES[@]}"; do
        echo "Checking status of critical service: $service"
        systemctl status "$service"
        if [ $? -ne 0 ]; then
            echo "Critical service $service is not running properly."
            return 1
        fi
    done
    # Capture the exit code
    exit_code=$?
    # Return the exit code
    return $exit_code
}

# Function to enable and configure SELinux/AppArmor
enable_security_framework() {
    if [ -f /etc/debian_version ]; then
        echo "Configuring AppArmor on Debian-based system..."
        apt-get update && apt-get install -y apparmor apparmor-utils
        systemctl enable apparmor && systemctl start apparmor
        apparmor_status
    elif [ -f /etc/redhat-release ]; then
        echo "Configuring SELinux on RedHat-based system..."
        yum install -y policycoreutils selinux-policy-targeted
        setenforce 1
        sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
        getenforce
    else
        echo "Unsupported OS. Exiting..."
        exit 1
    fi
    echo "Security framework configured."
}


# Call the functions
configure_secure_dns
configure_time_sync
secure_kernel_params
enforce_password_expiry
disable_usb_ports
remove_unnecessary_packages
enable_security_framework


echo "002-critical-standards.sh completed successfully."
