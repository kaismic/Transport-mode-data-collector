import argparse
import hashlib
import json
from datetime import datetime, timezone


def main():
    parser = argparse.ArgumentParser(description="Create a hashed invite code item.")
    parser.add_argument("--code", required=True, help="Invite code shared with a participant.")
    parser.add_argument("--participant-id", required=True, help="Pseudonymous participant ID.")
    args = parser.parse_args()

    code = args.code.strip().upper()
    item = {
        "code_hash": hashlib.sha256(code.encode("utf-8")).hexdigest(),
        "participant_id": args.participant_id,
        "active": True,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    print(json.dumps(item, indent=2))


if __name__ == "__main__":
    main()
