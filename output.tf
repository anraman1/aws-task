output "vpc_id" {
  value = aws_vpc.icg.id
}

output "subnet_ids" {
  value = {
    for k, v in aws_subnet.db_subnet : k => v.id
  }
}

output "asg_name" {
  value =  aws_aws_autoscaling_group.app_asg 
  
}

output "lb_dns_name" {
  value = aws_lb.app_lb.dns_name
  
}