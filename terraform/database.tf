resource "aws_db_subnet_group" "this" {
  name        = "${local.name}-db-isolated"
  description = "Isolated subnets for the PostgreSQL instance. No route to the internet."
  subnet_ids  = aws_subnet.isolated[*].id
}

resource "aws_db_parameter_group" "this" {
  name        = "${local.name}-postgres16"
  family      = "postgres16"
  description = "Require TLS for PostgreSQL connections."

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${local.name}-postgres"
  engine         = "postgres"
  engine_version = "16.15"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = "info"
  username                    = "info_admin"
  manage_master_user_password = true

  multi_az                = true
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.database.id]
  parameter_group_name    = aws_db_parameter_group.this.name
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot   = true

  deletion_protection      = false
  skip_final_snapshot      = true
  delete_automated_backups = true
  apply_immediately        = true

  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = false
  auto_minor_version_upgrade      = true

  tags = {
    Name = "${local.name}-postgres"
  }

  # RDS cannot move an instance to another subnet group in the same VPC.
  lifecycle {
    replace_triggered_by = [aws_db_subnet_group.this]
  }

  depends_on = [aws_cloudwatch_log_group.database]
}

resource "aws_cloudwatch_log_group" "database" {
  name              = "/aws/rds/instance/${local.name}-postgres/postgresql"
  retention_in_days = 14
}

resource "aws_secretsmanager_secret" "reader" {
  name                    = "${local.name}/reader"
  description             = "Password for the read-only PostgreSQL role used by GET /info."
  recovery_window_in_days = 0
}
