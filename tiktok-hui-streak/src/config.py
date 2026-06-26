from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = PROJECT_ROOT / "config.yaml"
SESSION_DIR = PROJECT_ROOT / ".session"
STORAGE_STATE_PATH = SESSION_DIR / "tiktok_storage.json"


@dataclass(frozen=True)
class AppConfig:
    friend_name: str
    message: str
    send_time: str
    headless: bool
    page_timeout_seconds: int


def load_config(path: Path = CONFIG_PATH) -> AppConfig:
    if not path.exists():
        raise FileNotFoundError(
            f"Missing {path}. Copy config.example.yaml to config.yaml and edit it."
        )

    with path.open(encoding="utf-8") as handle:
        raw = yaml.safe_load(handle) or {}

    friend_name = str(raw.get("friend_name", "")).strip()
    if not friend_name:
        raise ValueError("config.yaml: friend_name is required")

    message = str(raw.get("message", "HUI")).strip() or "HUI"
    send_time = str(raw.get("send_time", "09:00")).strip()

    return AppConfig(
        friend_name=friend_name,
        message=message,
        send_time=send_time,
        headless=bool(raw.get("headless", True)),
        page_timeout_seconds=int(raw.get("page_timeout_seconds", 30)),
    )
