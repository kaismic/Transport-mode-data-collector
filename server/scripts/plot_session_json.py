import gzip
import json
from pathlib import Path
from typing import Optional, Sequence

try:
    import matplotlib.pyplot as plt
    import pandas as pd
except ModuleNotFoundError as exc:
    raise SystemExit(
        "Missing plotting dependency. Install with: "
        "python -m pip install pandas matplotlib"
    ) from exc


SCRIPT_DIR = Path(__file__).resolve().parent
INPUT_PATH_FILE = SCRIPT_DIR / "plot-data-path.txt"

# Optional: set to a .png path to save the figure as well as displaying it.
OUTPUT_IMAGE_PATH: Optional[Path] = None

# Large sessions can make matplotlib sluggish. Set to None to plot every sample.
MAX_PLOT_POINTS: Optional[int] = 20000


SENSOR_GROUPS = (
    ("Acceleration", ("ax", "ay", "az"), "m/s^2"),
    ("Gyroscope", ("gx", "gy", "gz"), "rad/s"),
    ("Magnetometer", ("mx", "my", "mz"), "uT"),
    ("Pressure", ("p",), "hPa"),
)


def main():
    input_path = read_input_path(INPUT_PATH_FILE)
    payload = load_payload(input_path)
    samples = payload.get("samples")
    if not isinstance(samples, list) or not samples:
        raise ValueError(f"No samples found in {input_path}")

    df = prepare_samples(samples)
    plot_session(df, session_title(payload), OUTPUT_IMAGE_PATH)


def read_input_path(path_file):
    if not path_file.exists():
        raise FileNotFoundError(
            f"Create {path_file} and put the session JSON path in it."
        )

    for line in path_file.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if value and not value.startswith("#"):
            return resolve_input_path(value.strip("\"'"), path_file.parent)

    raise ValueError(f"Put a session JSON path in {path_file}.")


def resolve_input_path(path_text, base_dir):
    path = Path(path_text).expanduser()
    if path.is_absolute() or path.exists():
        return path
    return base_dir / path


def load_payload(path):
    if not path:
        raise ValueError(f"Put a session JSON path in {INPUT_PATH_FILE}.")

    if not path.exists():
        raise FileNotFoundError(path)

    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)

    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def prepare_samples(samples):
    df = pd.DataFrame(samples)
    if "ts" not in df.columns:
        raise ValueError("Sample data must include a 'ts' timestamp column.")

    numeric_columns = ["ts"]
    for _, columns, _ in SENSOR_GROUPS:
        numeric_columns.extend(columns)

    for column in numeric_columns:
        if column in df.columns:
            df[column] = pd.to_numeric(df[column], errors="coerce")

    df = df.dropna(subset=["ts"]).sort_values("ts").reset_index(drop=True)
    if df.empty:
        raise ValueError("No samples have a valid 'ts' timestamp.")

    df["time_s"] = (df["ts"] - df["ts"].iloc[0]) / 1000.0
    if MAX_PLOT_POINTS and len(df) > MAX_PLOT_POINTS:
        stride = max(1, (len(df) + MAX_PLOT_POINTS - 1) // MAX_PLOT_POINTS)
        df = df.iloc[::stride].reset_index(drop=True)

    return df


def plot_session(df, title, output_path):
    fig, axes = plt.subplots(
        len(SENSOR_GROUPS),
        1,
        figsize=(14, 10),
        sharex=True,
        constrained_layout=True,
    )
    fig.suptitle(title)

    for axis, (name, columns, unit) in zip(axes, SENSOR_GROUPS):
        plot_sensor_group(axis, df, name, columns, unit)

    axes[-1].set_xlabel("Time since first sample (seconds)")

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(output_path, dpi=150)
        print(f"Saved figure to {output_path}")

    plt.show()


def plot_sensor_group(axis, df, name, columns, unit):
    available_columns = columns_with_values(df, columns)
    axis.set_title(name)
    axis.set_ylabel(unit)
    axis.grid(True, alpha=0.3)

    if not available_columns:
        axis.text(
            0.5,
            0.5,
            "No data",
            ha="center",
            va="center",
            transform=axis.transAxes,
        )
        return

    for column in available_columns:
        axis.plot(df["time_s"], df[column], linewidth=0.9, label=column)

    axis.legend(loc="upper right")


def columns_with_values(df, columns: Sequence[str]):
    return [
        column
        for column in columns
        if column in df.columns and df[column].notna().any()
    ]


def session_title(payload):
    session_id = payload.get("session_id", "unknown session")
    vehicle_type = payload.get("vehicle_type")
    phone_position = payload.get("phone_position")
    details = [str(session_id)]
    if vehicle_type:
        details.append(str(vehicle_type))
    if phone_position:
        details.append(str(phone_position))
    return " | ".join(details)


if __name__ == "__main__":
    main()
