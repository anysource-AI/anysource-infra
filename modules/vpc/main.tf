locals {
  private_azs = [for i in range(length(var.private_subnets)) : element(var.region_az, i % length(var.region_az))]
  public_azs  = [for i in range(length(var.public_subnets)) : element(var.region_az, i % length(var.region_az))]
  tags_all = {
    "environment" = var.environment
    "name"        = var.project
  }
  flow_log_cloudwatch_log_group_name = "/aws/vpc-flow-log/${var.project}-${var.environment}"
  flow_log_iam_role_name = "vpc-flow-logs-role-${var.project}-${var.environment}"
}
/////////////////////////////////////////////////////////////////////////////////////////
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project}-${var.environment}"
  }
}
/////////////////////////////////////////////////////////////////////////////////////////

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-${var.environment}"
    environment = var.environment
    name        = var.project
  }
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
    gateway_id = aws_internet_gateway.main.id
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
/////////////////////////////////////////////////////////////////////////////////////////
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = local.flow_log_cloudwatch_log_group_name
  retention_in_days = var.flow_log_cloudwatch_log_group_retention_in_days
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = local.flow_log_iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs" {
  role       = aws_iam_role.vpc_flow_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_flow_log" "vpc" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  vpc_id               = aws_vpc.main.id
  traffic_type         = var.flow_log_traffic_type
  tags = {
    Name        = "${var.project}-${var.environment}-vpc-flow-log"
    Environment = var.environment
    Project     = var.project
  }
}
