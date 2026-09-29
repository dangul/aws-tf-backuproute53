import boto3
import logging
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

def format_record_bind(record):
    record_type = record["Type"]
    name = record["Name"].rstrip(".")
    ttl = record.get("TTL")

    lines = []

    if "AliasTarget" in record:
        target = record["AliasTarget"]["DNSName"].rstrip(".")
        lines.append(f"; ALIAS {name} -> {target} ({record_type})")
        alias_ttl = ttl if ttl is not None else 60
        lines.append(f"{name}. {alias_ttl} IN {record_type} {target} ; alias")
        return "\n".join(lines)

    values = [r["Value"] for r in record.get("ResourceRecords", [])]

    if not values and record_type not in ("NS", "SOA"):
        return ""

    ttl_str = str(ttl) if ttl is not None else "60"
    for value in values:
        lines.append(f"{name}. {ttl_str} IN {record_type} {value}")

    return "\n".join(lines)

def backup_zone(zone, date_str, bucket_name, route53_client, s3_client):
    raw_zone_id = zone["Id"]
    zone_id = raw_zone_id.split("/")[-1]
    zone_name = zone["Name"]

    logger.info(f"Let's backup zone: {zone_name} (ID: {zone_id})")

    try:
        paginator = route53_client.get_paginator("list_resource_record_sets")
        records = []
        for page in paginator.paginate(HostedZoneId=zone_id):
            records.extend(page["ResourceRecordSets"])

        logger.info(f"Found {len(records)} records in zone {zone_name}.")

        formatted = []
        for rec in records:
            try:
                out = format_record_bind(rec)
                if out:
                    formatted.append(out)
            except Exception as e:
                logger.exception(f"Error formatting record {rec.get('Name')} [{rec.get('Type')}] in zone {zone_name}: {e}")

        backup_data = "\n".join(formatted) + "\n"
        backup_filename = f"{date_str}/{zone_name.rstrip('.')}.zone"

        s3_client.put_object(
            Bucket=bucket_name,
            Key=backup_filename,
            Body=backup_data.encode("utf-8"),
            ContentType="text/plain; charset=utf-8",
        )
        logger.info(f"Zone {zone_name} stored as {backup_filename}.")

    except Exception as e:
        logger.exception(f"Backup failed for zone {zone_name} (ID: {zone_id}): {e}")
        raise

def lambda_handler(event, context):
    logger.info("Lambda function started.")
    if os.environ.get("TEST"):
        sns_client = boto3.client("sns")
        sns_client.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Subject="Route 53 backup test notification",
            Message="Test notification from the Route 53 backup Lambda.",
        )
        logger.info("Test notification sent.")

    route53_client = boto3.client("route53")

    zones = []
    paginator = route53_client.get_paginator("list_hosted_zones")
    for page in paginator.paginate():
        zones.extend(page["HostedZones"])

    logger.info(f"Found {len(zones)} hosted zones.")

    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")

    bucket_name = os.environ["S3_BUCKET_NAME"]
    s3_client = boto3.client("s3")

    errors = 0
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(backup_zone, z, date_str, bucket_name, route53_client, s3_client) for z in zones]
        for f in as_completed(futures):
            try:
                f.result()
            except Exception:
                errors += 1

    if errors:
        msg = f"Backup complete but {errors} zone(s) failed. See logs."
        logger.warning(msg)
        return {"statusCode": 207, "body": msg}

    logger.info("Backup completed successfully!")
    return {"statusCode": 200, "body": "Backup completed successfully!"}