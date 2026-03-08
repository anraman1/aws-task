variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "dbs" {
  description = "Declare the EC2 instances information"
  type        = list(map(string))

  default = [
    {
      name        = "ec2-db1"
      cidr        = "192.168.1.0/24"
      subnet_name = "private-sub-db1"
      route_table_name = "private-rt-db1"
      az          = "us-east-1a"
      public_ip     = "false"
    },
    {
      name        = "ec2-app2"
      cidr        = "192.168.2.0/24"
      subnet_name = "public-sub-app2"
      route_table_name = "public-rt-app2"
      az          = "us-east-1b"
      public_ip     = "true"
    },
   {
      name        = "ec2-app1"
      cidr        = "192.168.3.0/24"
      subnet_name = "public-sub-app1"
      route_table_name = "public-rt-app1"
      az          = "us-east-1a"
      public_ip     = "true"
    }
    
  ]
}
variable "vpc_name" {
  type    = string
  default = "icg"
}
