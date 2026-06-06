import argparse
import gzip
import json

import boto3
from boto3.dynamodb.conditions import Attr


def main():
    parser = argparse.ArgumentParser(description="List or download received sessions.")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--table", default="TransportSessions")
    parser.add_argument("--download-s3-key")
    args = parser.parse_args()

    if args.download_s3_key:
        session = load_session(args.bucket, args.download_s3_key)
        print(json.dumps(session, indent=2))
        return

    ddb = boto3.resource("dynamodb").Table(args.table)
    resp = ddb.scan(FilterExpression=Attr("status").eq("received"))
    print(json.dumps(resp.get("Items", []), indent=2, default=str))


def load_session(bucket, s3_key):
    obj = boto3.client("s3").get_object(Bucket=bucket, Key=s3_key)
    raw = gzip.decompress(obj["Body"].read())
    return json.loads(raw)


if __name__ == "__main__":
    main()
