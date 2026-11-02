"""Database helpers shared by the Lambda functions.

The password is read from Secrets Manager at runtime. It is never written to
the function response or to Terraform.
"""

import json
import os
import ssl

import boto3
import pg8000.native

_REQUIRED = ("username", "password", "host", "port", "dbname")
_ALIASES = {
    "username": ("username", "user"),
    "password": ("password",),
    "host": ("host", "hostname"),
    "port": ("port",),
    "dbname": ("dbname", "dbName", "database"),
}


def load_secret(arn, defaults=None):
    response = boto3.client("secretsmanager").get_secret_value(SecretId=arn)
    raw = response["SecretString"]
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        parsed = {"password": raw}
    if not isinstance(parsed, dict):
        parsed = {"password": raw}

    secret = dict(defaults or {})
    for field, names in _ALIASES.items():
        for name in names:
            if parsed.get(name) not in (None, ""):
                secret[field] = parsed[name]
                break

    missing = [field for field in _REQUIRED if field not in secret]
    if missing:
        # Key names only. Values stay out of the logs.
        raise RuntimeError(
            "secret is missing required fields: " + ",".join(missing)
            + "; keys=" + ",".join(sorted(parsed))
        )
    return secret


def connect(secret):
    cafile = os.path.join(os.path.dirname(__file__), "global-bundle.pem")
    context = ssl.create_default_context(cafile=cafile)
    return pg8000.native.Connection(
        secret["username"],
        password=secret["password"],
        host=secret["host"],
        port=int(secret["port"]),
        database=secret["dbname"],
        ssl_context=context,
        timeout=8,
    )
