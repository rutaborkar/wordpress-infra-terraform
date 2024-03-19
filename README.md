# Terraform Infrastructure Deployment for 3-Tier Architecture

This repository contains Terraform configuration files to deploy a 3-tier architecture infrastructure on AWS. The infrastructure includes networking components, security groups, S3 bucket, CloudFront CDN, RDS database, Auto Scaling Group (ASG) with an Application Load Balancer (ALB), and IAM roles and policies.

## Infrastructure Components

- **VPC**: Creates a Virtual Private Cloud with specified CIDR block.
- **Internet Gateway**: Provides internet access to resources within the VPC.
- **Subnets**: Creates public and private subnets within the VPC.
- **Security Groups**: Defines security rules for EC2 instances and database access.
- **S3 Bucket**: Sets up an S3 bucket for media uploads and code backup.
- **CloudFront CDN**: Configures a CDN for low-latency content delivery.
- **IAM Policies and Roles**: Manages permissions for accessing S3 and other AWS services.
- **RDS Database**: Sets up a MySQL database instance with multi-AZ deployment.
- **Auto Scaling Group**: Launches EC2 instances in response to demand with ALB and ASG.
- **Launch Template**: Defines the configuration for EC2 instances.
- **Auto Scaling Policies**: Implements scaling policies based on CPU utilization.

## Configuration Variables

- `s3_origin_id`: ID for the S3 origin in CloudFront.
- `bucket_name`: Name of the S3 bucket.
- `inbound_port_production_ec2`: List of inbound ports allowed on production instances.
- `db_name`, `db_user`, `db_password`: Database configuration.
- `instance_type`, `instance_ami`: EC2 instance type and AMI ID.
- `availability_zone`: List of availability zones for subnets.
- `vpc_cidr`: CIDR block for the VPC.
- `subnet_cidrs`: List of CIDR blocks for subnets.
- `target_application_port`: Application port for the ALB target group.

## Usage

1. Clone this repository.
2. Install Terraform if not already installed.
3. Set up AWS credentials for Terraform.
4. Modify the `variables.tf` file to customize the configuration.
5. Run `terraform init` to initialize the working directory.
6. Run `terraform plan` to preview the changes.
7. Run `terraform apply` to apply the changes and create the infrastructure.
