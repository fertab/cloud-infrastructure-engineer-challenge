"""GET /info. Connects to PostgreSQL and reports whether it worked."""

import json
import logging
import os

from db import connect, load_secret

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    try:
        secret = load_secret(os.environ["READER_SECRET_ARN"])
        connection = connect(secret)
        try:
            version, current_user = connection.run("SELECT version(), current_user")[0]
        finally:
            connection.close()
    except Exception:
        logger.exception("database connection failed")
        return _response(503, {"connected": False, "error": "database unreachable"})

    return _response(
        200,
        {
            "connected": True,
            "engine": "postgresql",
            "version": version,
            "current_user": current_user,
            "database": secret["dbname"],
            "instance_class": os.environ["DB_INSTANCE_CLASS"],
            "multi_az": os.environ["DB_MULTI_AZ"] == "true",
            "region": os.environ["AWS_REGION"],
        },
    )


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }
