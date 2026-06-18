import hashlib
from datetime import datetime, timezone
import json


def create_invite_code_item(code: str, participant_id: str) -> dict:
    item = {
        "code_hash": hashlib.sha256(code.encode("utf-8")).hexdigest(),
        "participant_id": participant_id,
        "active": True,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    return item

if __name__ == "__main__":
    with open("scripts/invite_codes.csv", "r") as f:
        for line in f:
            code, participant_id = line.strip().split(",")
            item = create_invite_code_item(code, participant_id)
            # json_str = json.dumps(item, )
            sql = "INSERT INTO TransportInviteCodes VALUE {};".format(item)
            print(sql)