provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

#Create a VPC

resource "aws_vpc" "vpcmain" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "mainvpc"
  }
}

#Create Internet gateway

resource "aws_internet_gateway" "gatewaymain" {
  vpc_id = aws_vpc.vpcmain.id

  tags = {
    "Name" = "maingateway"
  }
}

#Create Custom Route Table

resource "aws_route_table" "routetablemain" {
  vpc_id = aws_vpc.vpcmain.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gatewaymain.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gatewaymain.id
  }

  tags = {
    Name = "mainroutetable"
  }
}

#Create a subnet

resource "aws_subnet" "subnetmain-1" {
  vpc_id = aws_vpc.vpcmain.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "mainsubnet-1"
  }
}

#Associate subnet with route table

resource "aws_route_table_association" "assoroutetablemain" {
  subnet_id      = aws_subnet.subnetmain-1.id
  route_table_id = aws_route_table.routetablemain.id
}

#Create security group to allow port 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.vpcmain.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "port-security"
  }
}

#Create a network interface with an ip in the subnet

resource "aws_network_interface" "networkinterfacemain" {
  subnet_id       = aws_subnet.subnetmain-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  tags = {
    "Name" = "mainnetworkinterface"
  }
}

#Assign an elastic IP to the network Interface

resource "aws_eip" "maineip" {
  vpc                       = true
  network_interface         = aws_network_interface.networkinterfacemain.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gatewaymain
  ]

  tags = {
    "Name" = "eipmain"
  }
}

#Create Ubuntu Server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "webserver"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.networkinterfacemain.id
  }

  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemct1 start apache2
  sudo bash -c 'echo your very first web server > /var/www/html/index.html'
  EOF

  tags = {
    "Name" = "webservermain"
  }
}