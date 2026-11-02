# info

Terraform deployment of `GET /info` on AWS: API Gateway, a Lambda in private subnets, and PostgreSQL on RDS.

Terraform is the tool the challenge asks for. `terraform apply` creates the stack and `terraform destroy` removes it.

## What gets created

- VPC `10.42.0.0/16` in two availability zones
- One public subnet and one NAT gateway per zone
- Two private subnets for the Lambda functions, with a NAT route
- Two isolated subnets for the database, with no route to the internet
- RDS PostgreSQL 16, `db.t4g.micro`, Multi-AZ, encrypted, TLS required, 7-day backups
- Lambda `info` (Python 3.12, arm64) behind an HTTP API route `GET /info`
- Lambda `info-bootstrap`, private, creates the `info_reader` role
- Secrets Manager for both passwords. Terraform stores secret ARNs, not password values
- CloudWatch logs (14 days), VPC flow logs, and alarms for database CPU, free storage, and Lambda errors

The API route is throttled to 5 requests per second. A failed database connection returns `503` with `database unreachable`. The exception stays in CloudWatch.

`deletion_protection` is off and no final snapshot is kept, so `terraform destroy` can remove the stack. Backups still run while the instance exists.

## Requirements

- Terraform 1.5 or newer
- Python 3 with `pip`
- `curl` (the package script downloads the RDS CA bundle)
- AWS credentials in the environment. The region default is `us-east-2`

## Deploy

```bash
export AWS_PROFILE=nanlabs
cd terraform
terraform init
terraform apply
```

`terraform output api_url` prints the endpoint.

## Check

```bash
curl "$(terraform output -raw api_url)"
```

A healthy response has `"connected": true`, `"current_user": "info_reader"`, and the PostgreSQL version. Lambda logs are in `/aws/lambda/info`.

## Destroy

```bash
export AWS_PROFILE=nanlabs
cd terraform
terraform destroy
```

Two NAT gateways bill about $0.045 per hour each, plus $0.005 per hour for each public IPv4 address. The Multi-AZ `db.t4g.micro` instance is $0.032 per hour. Destroy the stack when it is no longer needed.
