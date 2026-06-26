#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
import time
from datetime import datetime, timedelta

import schedule

from src.config import load_config
from src.login import run_interactive_login
from src.sender import send_daily_message


def _parse_send_time(send_time: str) -> tuple[int, int]:
    try:
        hour_str, minute_str = send_time.split(":", 1)
        hour = int(hour_str)
        minute = int(minute_str)
    except ValueError as exc:
        raise SystemExit(f"Invalid send_time '{send_time}'. Use HH:MM (24h).") from exc

    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        raise SystemExit(f"Invalid send_time '{send_time}'. Hour must be 0-23, minute 0-59.")

    return hour, minute


def cmd_login() -> None:
    config = load_config()
    run_interactive_login(config)


def cmd_test() -> None:
    config = load_config()
    send_daily_message(config, headless=False)


def cmd_send_now() -> None:
    config = load_config()
    send_daily_message(config)


def cmd_schedule() -> None:
    config = load_config()
    hour, minute = _parse_send_time(config.send_time)

    def job() -> None:
        try:
            send_daily_message(config)
        except Exception as exc:
            print(f"[{datetime.now().isoformat(timespec='seconds')}] ERROR: {exc}")

    schedule.every().day.at(f"{hour:02d}:{minute:02d}").do(job)

    now = datetime.now()
    next_run = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if next_run <= now:
        next_run += timedelta(days=1)

    print("TikTok HUI streak bot is running.")
    print(f"Friend: {config.friend_name}")
    print(f"Message: {config.message}")
    print(f"Daily send time: {config.send_time} (local)")
    print(f"Next run: {next_run.strftime('%Y-%m-%d %H:%M:%S')}")
    print("Leave this terminal open, or install the background job from README.\n")

    while True:
        schedule.run_pending()
        time.sleep(1)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Send a daily TikTok DM to keep your streak alive."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("login", help="One-time TikTok login (saves session)")
    subparsers.add_parser("test", help="Send once with browser visible")
    subparsers.add_parser("send-now", help="Send once using saved session")
    subparsers.add_parser("schedule", help="Run daily scheduler in this terminal")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    commands = {
        "login": cmd_login,
        "test": cmd_test,
        "send-now": cmd_send_now,
        "schedule": cmd_schedule,
    }

    try:
        commands[args.command]()
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
