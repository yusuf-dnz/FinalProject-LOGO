resource "aws_security_group" "default_sg" {
  name        = "default-sg"
  description = "All rules"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "port 80"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["10.1.0.0/16"]
    security_groups = [aws_security_group.app_security.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "default-sg"
  }
}

resource "aws_security_group" "app_security" {
  name        = "app_security"
  description = "All rules"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app_security"
  }
}
