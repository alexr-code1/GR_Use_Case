#Log-In Credentials block with access_key, secret_key, region 
provider "aws" {
	access_key = ""
	secret_key = ""
	region = "us-east-1"
}

#Key Pair to control EC2 login access  
resource "aws_key_pair" "key" {
  key_name   = "key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
}

#Security group resource: 
#Ingress block 1 restricts inbound access to SSH on Port 22
#Ingress block 2 restricts inbound access to HTTP on Port 80
#Egress block restricts outbound traffic on Port 0
resource "aws_security_group" "ssh-http" { 
  name        = "ssh-http"
  description = "Restrict Type to HTTP and SSH traffic"
  ingress {
     from_port   = 22
     to_port     = 22
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
     from_port   = 80
     to_port     = 80
     protocol   = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
  egress {
     from_port       = 0
     to_port         = 0
     protocol        = "-1"
     cidr_blocks     = ["0.0.0.0/0"]
    }
}

#Create EC2 Instance with t2.micro General Purpose instance type (Ideal Use Case: Webserver) in Us-East-1a region 
#Attach security group, key_name, bash script to start apache, serve index.html from /var directory 
resource "aws_instance" "test-instance" {
  ami           = "ami-04902260ca3d33422"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  security_groups   = ["${aws_security_group.ssh-http.name}"]
  key_name = "key"
  user_data = <<-EOF
               #! /bin/bash
               sudo yum install httpd -y
               sudo systemctl start httpd
               sudo systemctl enable httpd
               echo "<h1>Hello GR World!" | sudo tee /var/www/html/index.html
 EOF
  tags = {
       Name = "webserver"
  }
}

#Assign Elastic Block Storage resource with 1 GB of storage 
resource "aws_ebs_volume" "data-vol" {
 availability_zone = "us-east-1a"
 size = 1
 tags = {
        Name = "data-volume"
 }
}

#Attach EBS volume to EC2
resource "aws_volume_attachment" "test-vol" {
 device_name = "/dev/sdc"
 volume_id = "${aws_ebs_volume.data-vol.id}"
 instance_id = "${aws_instance.test-instance.id}"
}

#Create Elastic File System Resource 
resource "aws_efs_file_system" "test-efs" {
   creation_token = "test-efs"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
tags = {
     Name = "test_efs"
   }
}

#Mount EFS target on EC2 and attach to EBS Volume
resource "aws_efs_mount_target" "test-efs-mt" {
   file_system_id = "${aws_efs_file_system.test-efs.id}"
   subnet_id = "${aws_subnet.subnet-efs.id}"
  # security_groups = ["${aws_security_group.ingress-efs-test.id}"]
}

#Create VPC resource for Subnet resource
resource "aws_vpc" "test-vpc" {
   cidr_block = "10.0.0.0/16"
   enable_dns_hostnames = true
   enable_dns_support = true
    tags = {
      Name = "main"
     }
}

#Create Subnet resource for EFS mount target 
resource "aws_subnet" "subnet-efs" {
   cidr_block = "${cidrsubnet(aws_vpc.test-vpc.cidr_block, 8, 8)}"
   vpc_id = "${aws_vpc.test-vpc.id}"
   availability_zone = "us-east-1a"
}

#Assign Static IP
#Typically IPv4 for permanent address  
resource "aws_eip" "byoip-ip" {
  vpc              = true
  #instance = aws_instance.main.id
  #public_ipv4_pool = "ipv4pool-ec2-012345"
}

#Output block to display URL of 'Hello GR World!' index.html
#Copy URL from 'DNS=' Output in terminal, and Paste in Browser
output "DNS" {
  value = aws_instance.test-instance.public_dns
}