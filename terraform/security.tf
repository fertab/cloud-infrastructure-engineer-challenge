resource "aws_security_group" "database" {
  name        = "info-database"
  description = "PostgreSQL. Accepts traffic only from the Lambda functions."
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Unused. Removes the default allow-all egress rule."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  tags = {
    Name = "info-database"
  }
}

resource "aws_security_group" "lambda" {
  name        = "info-lambda"
  description = "Lambda functions. Outbound to PostgreSQL and Secrets Manager."
  vpc_id      = aws_vpc.this.id

  egress {
    description     = "PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
  }

  egress {
    description = "HTTPS for Secrets Manager through the NAT gateway"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "info-lambda"
  }
}

resource "aws_security_group_rule" "database_from_lambda" {
  type                     = "ingress"
  description              = "PostgreSQL from the Lambda functions"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.database.id
  source_security_group_id = aws_security_group.lambda.id
}
