import json
from decimal import Decimal


def loads_for_dynamodb(raw_json):
    return json.loads(raw_json, parse_float=Decimal)
