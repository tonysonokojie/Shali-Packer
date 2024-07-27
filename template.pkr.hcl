packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.4"
      source  = "github.com/digitalocean/digitalocean"
    }
  }
}

variable "aws_region" {
  default = "us-east-1"
}

variable "ami_tag" {
  type = string
  description = "Environment Description for the AMI"
  default = "sandbox"
}

variable "source_ami" {
  default = "ami-0e001c9271cf7f3b9"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ssh_username" {
  default = "ubuntu"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = "packer-cis-hardened-ami-${local.timestamp}"
}

source "amazon-ebs" "example" {
  region                    = var.aws_region
  source_ami                = var.source_ami
  instance_type             = var.instance_type
  ssh_username              = var.ssh_username
  ami_name                  = local.ami_name
  ami_description           = "A CIS hardened AMI created with Packer"
  associate_public_ip_address = true

  tags = {
    Name      = "packer-cis-hardened-ami"
    CreatedBy = "packer"
  }

  run_tags = {
    Name = "packer-builder"
  }
}

build {
  sources = ["source.amazon-ebs.example"]

   provisioner "file" {
    source      = "001-critical-standards.sh"
    destination = "/tmp/001-critical-standards.sh"
  }

  provisioner "file" {
    source      = "002-critical-standards.sh"
    destination = "/tmp/002-critical-standards.sh"
  }

  provisioner "file" {
    source      = "Packages_To_Delete.csv"
    destination = "/tmp/Packages_To_Delete.csv"
  }


  provisioner "shell" {
    inline = [
      "if [ ! -f /tmp/002-critical-standards-executed ]; then",
      "   sudo /tmp/002-critical-standards.sh",
      "   sudo touch /tmp/002-critical-standards-executed",
      "fi",
      "if [ ! -f /tmp/001-critical-standards-executed ]; then",
      "   sudo /tmp/001-critical-standards.sh ${var.ssh_username}",
      "   sudo touch /tmp/001-critical-standards-executed",
      "fi"
    ]
  }
}