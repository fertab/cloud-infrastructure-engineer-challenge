"""Creates the read-only database role and stores its password in Secrets Manager.

Runs once from Terraform, inside the private network. The password is generated
here and never returned to Terraform.
"""

import json
import logging
import os
import secrets
import time

import boto3

from db import connect, load_secret

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ROLE = "info_reader"


def handler(event, context):
    master = load_secret(
        os.environ["MASTER_SECRET_ARN"],
        {
            "username": os.environ["DB_USER"],
            "host": os.environ["DB_HOST"],
            "port": os.environ["DB_PORT"],
            "dbname": os.environ["DB_NAME"],
        },
    )
    password = secrets.token_urlsafe(32)
    connection = _connect_when_ready(master)
    try:
        _ensure_role(connection, password)
        _grant(connection, master["dbname"])
    finally:
        connection.close()

    boto3.client("secretsmanager").put_secret_value(
        SecretId=os.environ["READER_SECRET_ARN"],
        SecretString=json.dumps(
            {
                "username": ROLE,
                "password": password,
                "host": master["host"],
                "port": master["port"],
                "dbname": master["dbname"],
                "engine": "postgres",
            }
        ),
    )
    logger.info("read-only role is ready")
    return {"status": "ok"}


def _connect_when_ready(secret):
    delay_seconds = 3
    last_error = None
    for attempt in range(4):
        try:
            return connect(secret)
        except Exception as exc:
            last_error = exc
            logger.warning("database not ready (%s), attempt %s", type(exc).__name__, attempt + 1)
            time.sleep(delay_seconds)
    raise last_error


def _ensure_role(connection, password):
    exists = connection.run("SELECT 1 FROM pg_roles WHERE rolname = :role", role=ROLE)
    # CREATE ROLE cannot run inside an open transaction. Commit the previous
    # query, then run the utility statement on its own.
    verb = "ALTER ROLE" if exists else "CREATE ROLE"
    _utility(
        connection,
        "SELECT format('%s info_reader WITH LOGIN PASSWORD %L', :verb::text, :password::text)",
        verb=verb,
        password=password,
    )


def _grant(connection, dbname):
    _utility(
        connection,
        "SELECT format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', :dbname::text)",
        dbname=dbname,
    )
    _utility(
        connection,
        "SELECT format('GRANT CONNECT ON DATABASE %I TO info_reader', :dbname::text)",
        dbname=dbname,
    )


def _utility(connection, render_sql, **params):
    statement = connection.run(render_sql, **params)[0][0]
    connection.run("COMMIT")
    connection.run(statement)
