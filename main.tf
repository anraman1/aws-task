
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

resource "aws_instance" "db_instance" {

  for_each = {
    for db in var.dbs : db["name"] => db
  }

  ami               = data.aws_ami.amazon_linux.id
  instance_type     = var.instance_type
  subnet_id         = aws_subnet.db_subnet[each.key].id
  availability_zone = each.value["az"]

  tags = {
    Name = each.value["name"]
  }
}
