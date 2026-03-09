
resource "aws_vpc" "icg" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "db_subnet" {

  for_each = {
    for db in var.dbs : db["name"] => db
  }

  vpc_id            = aws_vpc.icg.id
  cidr_block        = each.value["cidr"]
  availability_zone = each.value["az"]

  tags = {
    Name = each.value["subnet_name"]
  }
}

# resource "aws_instance" "db_instance" {

#   for_each = {
#     for db in var.dbs : db["name"] => db
#   }
#   # use the ASG launch configuration for app instances and create EC2 instances only for dbs

#   ami               = data.aws_ami.amazon_linux.id
#   instance_type     = var.instance_type
#   subnet_id         = aws_subnet.db_subnet[each.key].id
#   #enable auto-assign public IP for app instances
#   availability_zone = each.value["az"]

#   tags = {
#     Name = each.value["name"]
#   }
# }


resource "aws_autoscaling_group" "app_asg" {
  desired_capacity = 2
  max_size         = 6
  min_size         = 2

  vpc_zone_identifier = [
    aws_subnet.db_subnet["ec2-app1"].id,
    aws_subnet.db_subnet["ec2-app2"].id
  ]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  health_check_type = "EC2"
}


resource "aws_route_table" "route_rt" {

  for_each = {
    for db in var.dbs : db["name"] => db
  }

  vpc_id = aws_vpc.icg.id

  tags = {
    Name = each.value["route_table_name"]
  }
}

resource "aws_route_table_association" "route_rt_assoc" {

  for_each = {
    for db in var.dbs : db["name"] => db
  }

  subnet_id      = aws_subnet.db_subnet[each.key].id
  route_table_id = aws_route_table.route_rt[each.key].id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.icg.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route" "public_route" {
    # add internet gateway route to public route tables
    for_each = {
        for db in var.dbs : db["name"] => db
         if strcontains(db["route_table_name"], "public")   
    }

    route_table_id         = aws_route_table.route_rt[each.key].id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.igw.id
}



# create a atuo-scaling group 
# resource "aws_autoscaling_group" "app_asg" {
#   name                      = "app-asg"
#   max_size                  = 3
#   min_size                  = 1
#   desired_capacity          = 1
#   vpc_zone_identifier       = [aws_subnet.db_subnet["ec2-app1"].id, aws_subnet.db_subnet["ec2-app2"].id]
#   launch_configuration      = aws_launch_configuration.app_launch_config.name
  

# }

resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"


   # assign public IP when launching instances 

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }


  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum install -y python3

              mkdir -p /var/www/html
              echo "Hello from $(hostname -f)" > /var/www/html/index.html

              cd /var/www/html
              python3 -m http.server 80 &
              EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "app-instance"
    }
  }
}

# create a target group and assing auto=scaling group to it
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.icg.id
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  lb_target_group_arn    = aws_lb_target_group.app_tg.arn
}

# create a target group and a load balancer to distribute traffic to the app instances in the ASG
resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.icg.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   
} 
}


resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets = [
    aws_subnet.db_subnet["ec2-app1"].id,
    aws_subnet.db_subnet["ec2-app2"].id
  ]
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


# resource "local_file" "install_script" {
#   content = <<-EOT
#             #!/bin/bash
#             yum install -y python3

#             mkdir -p /var/www/html
#             echo "Hello from $(hostname -f)" > /var/www/html/index.html

#             cd /var/www/html
#             python3 -m http.server 80 &
#             EOT
#   filename = "install.sh"
  
# }


resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Security group for the app instances"
  vpc_id      = aws_vpc.icg.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  
}
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
