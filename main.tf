#Create VPC
resource "aws_vpc" "infra_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  instance_tenancy     = "default"

  tags = {
    Name = "wp-architecture-vpc"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "tier_architecture_igw" {
  vpc_id = aws_vpc.infra_vpc.id
  tags = {
    Name = "wp-architecture-igw"
  }
}

#Create public subnet
resource "aws_subnet" "first_public_subnet" {
  vpc_id                  = aws_vpc.infra_vpc.id
  cidr_block              = var.subnet_cidrs[1]
  map_public_ip_on_launch = "true"
  availability_zone       = var.availability_zone[0]
  tags = {
    Name = "first ec2 public subnet"
  }
}

#Create second public subnet
resource "aws_subnet" "second_public_subnet" {
  vpc_id                  = aws_vpc.infra_vpc.id
  cidr_block              = var.subnet_cidrs[2]
  map_public_ip_on_launch = "true"
  availability_zone       = var.availability_zone[1]
  tags = {
    Name = "second ec2 public subnet"
  }
}

#Create database private subnet
resource "aws_subnet" "database_private_subnet" {
  vpc_id                  = aws_vpc.infra_vpc.id
  cidr_block              = var.subnet_cidrs[4]
  map_public_ip_on_launch = "false"
  availability_zone       = var.availability_zone[1]
  tags = {
    Name = "database private subnet"
  }
}

#Create database read replica private subnet
resource "aws_subnet" "database_read_replica_private_subnet" {
  vpc_id                  = aws_vpc.infra_vpc.id
  cidr_block              = var.subnet_cidrs[3]
  map_public_ip_on_launch = "false"
  availability_zone       = var.availability_zone[0]
  tags = {
    Name = "database read replica private subnet"
  }
}

#Create a security  group for ec2 instances group to allow traffic 
resource "aws_security_group" "production-instances-sg" {
  name        = "production-instances-sg"
  description = "Allow inbound traffic on port 22, 80 and 443"
  vpc_id      = aws_vpc.infra_vpc.id

  dynamic "ingress" {
    for_each = var.inbound_port_production_ec2
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create a security  group for DB to allow traffic on port 3306 from ec2 production security group
resource "aws_security_group" "database-sg" {
  name        = "database-sg"
  description = "security  group for database to allow traffic on port 3306 and from ec2 production security group"
  vpc_id      = aws_vpc.infra_vpc.id

  ingress {
    description     = "Allow traffic from port 3306 from ec2 production security group"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.production-instances-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create S3 bucket to backup media uploads and code 
resource "aws_s3_bucket" "my_wordpress_bucket" {
  bucket = var.bucket_name
  tags = {
    name = "wordpress-bucket"
  }
}

locals {
  s3_origin_id = var.s3_origin_id
}

#IAM policy for S3 access
resource "aws_iam_policy" "ec2_wordpress_policy" {
  name = "ec2_wordpress_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListAllMyBuckets"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${var.bucket_name}"
      },
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      },
    ]
  })
}

#Create IAM role for wordpress EC2 to allow S3 read/write access
resource "aws_iam_role" "ec2_wordpress_role" {
  name = "ec2_wordpress_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "RoleForEC2"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

#Attach IAM policy to IAM role
resource "aws_iam_role_policy_attachment" "ec2_wordpress_policy_attachment" {
  policy_arn = aws_iam_policy.ec2_wordpress_policy.arn
  role       = aws_iam_role.ec2_wordpress_role.name
}

#Create ALB
resource "aws_lb" "alb" {
  name               = "asg-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.production-instances-sg.id]
  subnets            = [aws_subnet.first_public_subnet.id, aws_subnet.second_public_subnet.id]
}

#Create ALB target group
resource "aws_lb_target_group" "alb_target_group" {
  name     = "asg-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.infra_vpc.id
}

#Add ALB listeners
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

#Create launch template
resource "aws_launch_template" "instances_configuration" {
  name_prefix            = "asg-instance"
  image_id               = var.instance_ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.production-instances-sg.id]
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "asg-instance"
  }

}

#Create autoscaling groups
resource "aws_autoscaling_group" "asg" {
  name                      = "asg"
  min_size                  = 3
  max_size                  = 6
  desired_capacity          = 3
  health_check_grace_period = 150
  health_check_type         = "EC2"
  vpc_zone_identifier       = [aws_subnet.first_public_subnet.id, aws_subnet.second_public_subnet.id]
  launch_template {
    id      = aws_launch_template.instances_configuration.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "production-instance"
    propagate_at_launch = true
  }

  depends_on = [
    aws_db_instance.rds_master,
  ]
}

#Create scaling policy
resource "aws_autoscaling_policy" "avg_cpu_policy_greater" {
  name                   = "avg-cpu-policy-greater"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.id
  # CPU Utilization is above 50
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }

}

#Link ASG with target groups
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.asg.id
  lb_target_group_arn    = aws_lb_target_group.alb_target_group.arn
}

#
resource "aws_db_subnet_group" "rds-database_subnet" {
  name       = "rds_database_subnet"
  subnet_ids = [aws_subnet.database_private_subnet.id, aws_subnet.database_read_replica_private_subnet.id]
}

resource "aws_db_instance" "rds_master" {
  identifier              = "master-rds-instance"
  allocated_storage       = 10
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  db_name                 = var.db_name
  username                = var.db_user
  password                = var.db_password
  backup_retention_period = 7
  multi_az                = true
  db_subnet_group_name    = aws_db_subnet_group.rds-database_subnet.id
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.database-sg.id]
  storage_encrypted       = true

  tags = {
    Name = "my-rds-master"
  }
}

