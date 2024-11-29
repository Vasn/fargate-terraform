resource "aws_route_table" "public_subnet_1a" {
  vpc_id = var.vpc_id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = var.firewall_a_endpoint_id
  }

  tags = {
    Name = "public-1a-route-table"
  }
}

resource "aws_route_table" "public_subnet_1b" {
  vpc_id = var.vpc_id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = var.firewall_b_endpoint_id
  }

  tags = {
    Name = "public-1b-route-table"
  }
}

resource "aws_route_table" "private_subnet_1a" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_gateway_a_id
  }

  tags = {
    Name = "app-1a-route-table"
  }
}

resource "aws_route_table" "private_subnet_1b" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_gateway_b_id
  }

  tags = {
    Name = "app-1b-route-table"
  }
}

resource "aws_route_table" "private_data_subnet" {
  vpc_id = var.vpc_id

  tags = {
    Name = "data-route-table"
  }
}

resource "aws_route_table" "igw_ingress" {
  vpc_id = var.vpc_id

  # In PROD, you should route directly to the cidr ranges you require, if not your supernet ranges will include cidr ranges which you do not intend traffic to pass through the firewall. 
  route {
    cidr_block      = "10.0.0.0/28"
    vpc_endpoint_id = var.firewall_a_endpoint_id
  }

  route {
    cidr_block      = "10.0.1.0/28"
    vpc_endpoint_id = var.firewall_b_endpoint_id
  }
}

resource "aws_route_table" "public_firewall_subnet" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }

  tags = {
    Name = "firewall-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_1a" {
  subnet_id      = var.public_subnet_1a_id
  route_table_id = aws_route_table.public_subnet_1a.id
}

resource "aws_route_table_association" "public_subnet_1b" {
  subnet_id      = var.public_subnet_1b_id
  route_table_id = aws_route_table.public_subnet_1b.id
}

resource "aws_route_table_association" "web_subnet" {
  subnet_id      = var.web_subnet_1a_id
  route_table_id = aws_route_table.private_subnet_1a.id
}

resource "aws_route_table_association" "app_subnet_1a" {
  subnet_id      = var.app_subnet_1a_id
  route_table_id = aws_route_table.private_subnet_1a.id
}

resource "aws_route_table_association" "app_subnet_1b" {
  subnet_id      = var.app_subnet_1b_id
  route_table_id = aws_route_table.private_subnet_1b.id
}

resource "aws_route_table_association" "data_subnet_1a" {
  subnet_id      = var.data_subnet_1a_id
  route_table_id = aws_route_table.private_data_subnet.id
}

resource "aws_route_table_association" "data_subnet_1b" {
  subnet_id      = var.data_subnet_1b_id
  route_table_id = aws_route_table.private_data_subnet.id
}

resource "aws_route_table_association" "igw" {
  gateway_id     = var.internet_gateway_id
  route_table_id = aws_route_table.igw_ingress.id
}

resource "aws_route_table_association" "firewall_subnet_1a" {
  subnet_id      = var.firewall_subnet_1a_id
  route_table_id = aws_route_table.public_firewall_subnet.id
}

resource "aws_route_table_association" "firewall_subnet_1b" {
  subnet_id      = var.firewall_subnet_1b_id
  route_table_id = aws_route_table.public_firewall_subnet.id
}