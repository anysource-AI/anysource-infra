locals {
  private_azs = [for i in range(length(var.private_subnets)) : element(var.region_az, i % length(var.region_az))]
  public_azs  = [for i in range(length(var.public_subnets)) : element(var.region_az, i % length(var.region_az))]
  tags_all = {
    "environment" = var.environment
    "name"        = var.project
  }
}
/////////////////////////////////////////////////////////////////////////////////////////
resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project}-${var.environment}"
  }
}
/////////////////////////////////////////////////////////////////////////////////////////

# Use existing internet gateway
data "aws_internet_gateway" "existing" {
  filter {
    name   = "internet-gateway-id"
    values = ["igw-087933d8675640630"]
  }
}

# Attach the existing internet gateway to our VPC
resource "aws_internet_gateway_attachment" "igw_attachment" {
  internet_gateway_id = data.aws_internet_gateway.existing.id
  vpc_id              = aws_vpc.main.id
}
/////////////////////////////////////////////////////////////////////////////////////////

resource "aws_subnet" "private" {
  count                   = length(var.private_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnets[count.index]
  map_public_ip_on_launch = false
  availability_zone       = local.private_azs[count.index]

  tags = merge(
    var.private_subnet_tags,
    local.tags_all,
    {
      "Name" = "${var.project}-${var.environment}-private-${local.private_azs[count.index]}"
    }
  )
}
/////////////////////////////////////////////////////////////////////////////////////////

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone       = local.public_azs[count.index]

  tags = merge(
    var.public_subnet_tags,
    local.tags_all,
    {
      "Name" = "${var.project}-${var.environment}-public-${local.public_azs[count.index]}"
    }
  )
}

/////////////////////////////////////////////////////////////////////////////////////////

resource "aws_eip" "nat" {
  count  = length(var.region_az)
  domain = "vpc"

  tags = {
    environment = var.environment
    name        = var.project
    Name        = "${var.project}-${var.environment}-${var.region_az[count.index]}"
  }
}
/////////////////////////////////////////////////////////////////////////////////////////


resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.region_az)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    environment = var.environment
    name        = var.project
    Name        = "${var.project}-${var.environment}-${var.region_az[count.index]}"
  }
}
/////////////////////////////////////////////////////////////////////////////////////////

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing.id
  }

  tags = {
    environment = var.environment
    name        = var.project
    Name        = "${var.project}-${var.environment}-public"
  }
}
/////////////////////////////////////////////////////////////////////////////////////////

resource "aws_route_table_association" "public" {
  count          = length(var.region_az)
  subnet_id      = aws_subnet.public.*.id[count.index]
  route_table_id = aws_route_table.public.id
}
/////////////////////////////////////////////////////////////////////////////////////////
resource "aws_route_table" "private" {
  count  = length(var.region_az)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }

  tags = {
    environment = var.environment
    name        = var.project
    Name        = "${var.project}-${var.environment}-private-${var.region_az[count.index]}"
  }
}
/////////////////////////////////////////////////////////////////////////////////////////

resource "aws_route_table_association" "private" {
  count          = length(var.region_az)
  subnet_id      = aws_subnet.private.*.id[count.index]
  route_table_id = aws_route_table.private[count.index].id
}
