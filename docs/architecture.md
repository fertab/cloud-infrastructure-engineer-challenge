# Layout

```text
Internet
   |
   v
API Gateway HTTP API          GET /info
   |
   v
Lambda (private subnets)      reads Secrets Manager via NAT
   |
   v
RDS PostgreSQL (isolated)     Multi-AZ, TLS, no route to the internet
```

| Piece | Role |
| --- | --- |
| API Gateway HTTP API | Public `GET /info`, throttled, access logs enabled |
| Lambda `info` | Runs `SELECT version(), current_user` and returns JSON |
| Lambda `info-bootstrap` | Creates `info_reader` and stores its password in Secrets Manager. No public route |
| NAT gateways | One per availability zone. Used for the Secrets Manager call. Database traffic does not use them |
| RDS | PostgreSQL 16, `db.t4g.micro`, Multi-AZ, encrypted storage, 7-day backups. Lives in isolated subnets with no default route |
| Security groups | Database accepts TCP 5432 only from the Lambda security group |

`info_reader` can connect and nothing else. The SQL text is fixed in the function.
