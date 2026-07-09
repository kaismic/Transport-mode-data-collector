import argparse
import json
import sys
from pathlib import Path

import query_sessions
from botocore.exceptions import MissingDependencyException


DEFAULT_CONFIG_FILE = Path(__file__).with_name("session-download.json")
DEFAULT_TABLE = "TransportSessions"
DEFAULT_OUTPUT_DIR = "downloaded_sessions"


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Download received sessions using a JSON config file."
    )
    parser.add_argument(
        "config_file",
        nargs="?",
        type=Path,
        default=DEFAULT_CONFIG_FILE,
        help=f"Download config JSON file. Defaults to {DEFAULT_CONFIG_FILE.name}.",
    )
    args = parser.parse_args(argv)

    config = read_config(args.config_file)
    result = run_from_config(config)
    print(json.dumps(result, indent=2, default=str))


def read_config(path):
    with path.open("r", encoding="utf-8") as f:
        config = json.load(f)
    if not isinstance(config, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return config


def run_from_config(config):
    bucket = required_config_value(config, "bucket")
    download_s3_key = config_value(config, "download-s3-key")

    if download_s3_key:
        return query_sessions.load_session(bucket, download_s3_key)

    if not config_bool(config, "sync-new", default=False):
        raise ValueError(
            'Download config must set "sync-new": true or provide "download-s3-key".'
        )

    output_dir = Path(config_value(config, "output-dir", DEFAULT_OUTPUT_DIR))
    checkpoint_file = config_value(config, "checkpoint-file")
    if checkpoint_file:
        checkpoint_file = Path(checkpoint_file)
    else:
        checkpoint_file = output_dir / ".download_checkpoint.json"

    return query_sessions.sync_new_sessions(
        bucket=bucket,
        table=config_value(config, "table", DEFAULT_TABLE),
        output_dir=output_dir,
        checkpoint_file=checkpoint_file,
        since_ms=config_int(config, "since-ms"),
        decompress=config_bool(config, "decompress", default=False),
        overwrite=config_bool(config, "overwrite", default=False),
    )


def required_config_value(config, key):
    value = config_value(config, key)
    if value is None or value == "":
        raise ValueError(f'Missing required download config value "{key}"')
    return value


def config_value(config, key, default=None):
    underscore_key = key.replace("-", "_")
    if key in config:
        return config[key]
    if underscore_key in config:
        return config[underscore_key]
    return default


def config_bool(config, key, default):
    value = config_value(config, key, default)
    if isinstance(value, bool):
        return value
    raise ValueError(f'Download config value "{key}" must be true or false')


def config_int(config, key):
    value = config_value(config, key)
    if value is None:
        return None
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    raise ValueError(f'Download config value "{key}" must be an integer')


if __name__ == "__main__":
    try:
        main()
    except MissingDependencyException as exc:
        query_sessions.print_aws_dependency_error(exc)
        sys.exit(2)
