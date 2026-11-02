resource "aws_apigatewayv2_api" "this" {
  name          = local.name
  protocol_type = "HTTP"
  description   = "Public GET /info endpoint."
}

resource "aws_apigatewayv2_integration" "info" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.info.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "info" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /info"
  target    = "integrations/${aws_apigatewayv2_integration.info.id}"
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${local.name}"
  retention_in_days = 14
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId = "$context.requestId"
      ip        = "$context.identity.sourceIp"
      routeKey  = "$context.routeKey"
      status    = "$context.status"
    })
  }

  depends_on = [aws_lambda_invocation.bootstrap]
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowAPIGatewayGetInfo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.info.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/GET/info"
}
