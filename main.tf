
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

