data "external" "info_package" {
  program = ["bash", "${path.module}/../scripts/package_lambda.sh", "info"]
}

data "external" "bootstrap_package" {
  program = ["bash", "${path.module}/../scripts/package_lambda.sh", "bootstrap"]
}

resource "aws_cloudwatch_log_group" "info" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "bootstrap" {
  name              = "/aws/lambda/${local.name}-bootstrap"
  retention_in_days = 14
}

resource "aws_lambda_function" "info" {
  function_name = local.name
  description   = "Answers GET /info with the PostgreSQL connection status."
  role          = aws_iam_role.info.arn
  runtime       = "python3.12"
  architectures = ["arm64"]
  handler       = "handler.handler"
  memory_size   = 256
  timeout       = 15

  filename         = data.external.info_package.result.path
  source_code_hash = data.external.info_package.result.hash

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      READER_SECRET_ARN = aws_secretsmanager_secret.reader.arn
      DB_INSTANCE_CLASS = aws_db_instance.this.instance_class
      DB_MULTI_AZ       = tostring(aws_db_instance.this.multi_az)
    }
  }

  depends_on = [
    aws_iam_role_policy.info,
    aws_cloudwatch_log_group.info,
  ]
}

resource "aws_lambda_function" "bootstrap" {
  function_name = "${local.name}-bootstrap"
  description   = "Creates the read-only database role. Not exposed to the internet."
  role          = aws_iam_role.bootstrap.arn
  runtime       = "python3.12"
  architectures = ["arm64"]
  handler       = "handler.handler"
  memory_size   = 256
  timeout       = 60

  filename         = data.external.bootstrap_package.result.path
  source_code_hash = data.external.bootstrap_package.result.hash

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      MASTER_SECRET_ARN = aws_db_instance.this.master_user_secret[0].secret_arn
      READER_SECRET_ARN = aws_secretsmanager_secret.reader.arn
      DB_USER           = aws_db_instance.this.username
      DB_HOST           = aws_db_instance.this.address
      DB_PORT           = tostring(aws_db_instance.this.port)
      DB_NAME           = aws_db_instance.this.db_name
    }
  }

  depends_on = [
    aws_iam_role_policy.bootstrap,
    aws_cloudwatch_log_group.bootstrap,
  ]
}

resource "aws_lambda_invocation" "bootstrap" {
  function_name = aws_lambda_function.bootstrap.function_name

  input = jsonencode({
    db_id            = aws_db_instance.this.id
    reader_secret_id = aws_secretsmanager_secret.reader.id
  })

  depends_on = [
    aws_db_instance.this,
    aws_lambda_function.bootstrap,
  ]

  lifecycle {
    replace_triggered_by = [aws_db_instance.this]
  }
}
