output "api_url" {
  description = "Public URL for GET /info."
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/info"
}

output "database_endpoint" {
  description = "Private PostgreSQL address. It is not reachable from the internet."
  value       = aws_db_instance.this.address
}

output "reader_secret_arn" {
  description = "Secrets Manager secret used by the Lambda. The value is not the password."
  value       = aws_secretsmanager_secret.reader.arn
}
