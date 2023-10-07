resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_password" "postgres" {
  for_each = local.environments

  length  = 16
  special = false
}

resource "aws_key_pair" "website" {
  key_name   = "website"
  public_key = tls_private_key.rsa_4096.public_key_openssh
}

resource "aws_eip" "website" {
  for_each = local.environments

  instance = aws_instance.website[each.key].id
}

resource "aws_security_group_rule" "allow_psql" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.website.id
}

resource "aws_security_group" "website" {
  name = "website"

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0", ]
    ipv6_cidr_blocks = ["::/0", ]
  }
}

resource "aws_security_group" "allow_http" {
  name = "allow_http"

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0", ]
    ipv6_cidr_blocks = ["::/0", ]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0", ]
    ipv6_cidr_blocks = ["::/0", ]
  }
}

resource "aws_instance" "website" {
  for_each = local.environments

  ami             = "ami-024e6efaf93d85776"
  instance_type   = each.value["machine_type"]
  key_name        = aws_key_pair.website.key_name
  security_groups = [aws_security_group.allow_http.name, aws_security_group.website.name, ]

  tags = {
    "Name" = "website-${each.key}"
    "Env"  = each.key
  }

  user_data = join("\n", [
    "#!/bin/bash",
    "apt-get update",
    "apt-get install docker -y",
    "echo \"${data.local_file.traefik.content_base64}\" | base64 -d > /opt/appstack/traefik/docker-compose.yml",
    "docker compose -f /opt/appstack/traefik/docker-compose.yml up -d",
    "echo \"${data.local_file.postgres.content_base64}\" | base64 -d > /opt/appstack/postgres/docker-compose.yml",
    "echo \"POSTGRES_PASSWORD=${random_password.postgres[each.key].result}\" >> /opt/appstack/postgres/.env",
    "echo \"POSTGRES_USER=${each.key}\" >> /opt/appstack/postgres/.env",
    "echo \"POSTGRES_DB=${each.key}\" >> /opt/appstack/postgres/.env",
    "docker compose -f /opt/appstack/traefik/docker-compose.yml up -d",
  ])
}

data "local_file" "traefik" {
  filename = "./stacks/traefik/docker-compose.yml"
}

data "local_file" "postgres" {
  filename = "./stacks/postgresql/docker-compose.yml"
}

resource "local_sensitive_file" "terraform_ssh_private_key" {
  content  = tls_private_key.rsa_4096.private_key_openssh
  filename = "./terraform.id_rsa"
}

resource "local_sensitive_file" "postgres_data" {
  for_each = local.environments

  content  = join("\n", [
    "POSTGRES_PASSWORD=${random_password.postgres[each.key].result}",
    "POSTGRES_USER=${each.key}",
    "POSTGRES_DB=${each.key}",
    "IP_ADDR=${aws_eip.website[each.key].public_ip}",
  ])
  filename = "${each.key}-db-data.secret"
}
