from __future__ import annotations

import platform
from pathlib import Path

from playwright.sync_api import Browser, BrowserContext, Page, Playwright

from .config import STORAGE_STATE_PATH

MESSAGES_URL = "https://www.tiktok.com/messages"


def _default_user_agent() -> str:
    if platform.system() == "Windows":
        return (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/122.0.0.0 Safari/537.36"
        )
    return (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    )


def ensure_session_dir() -> None:
    STORAGE_STATE_PATH.parent.mkdir(parents=True, exist_ok=True)


def launch_context(
    playwright: Playwright,
    *,
    headless: bool,
    storage_state: Path | None = STORAGE_STATE_PATH,
) -> tuple[Browser, BrowserContext]:
    ensure_session_dir()

    browser = playwright.chromium.launch(
        headless=headless,
        args=[
            "--disable-blink-features=AutomationControlled",
        ],
    )

    context_kwargs: dict = {
        "viewport": {"width": 1280, "height": 900},
        "user_agent": _default_user_agent(),
    }

    if storage_state and storage_state.exists():
        context_kwargs["storage_state"] = str(storage_state)

    context = browser.new_context(**context_kwargs)
    context.add_init_script(
        """
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined,
        });
        """
    )
    return browser, context


def save_storage_state(context: BrowserContext) -> None:
    ensure_session_dir()
    context.storage_state(path=str(STORAGE_STATE_PATH))


def open_messages_page(page: Page, timeout_ms: int) -> None:
    page.goto(MESSAGES_URL, wait_until="domcontentloaded", timeout=timeout_ms)
    page.wait_for_timeout(2000)


def is_login_page(page: Page) -> bool:
    url = page.url.lower()
    if "login" in url:
        return True

    login_text = page.get_by_text("Log in to TikTok", exact=False)
    try:
        return login_text.count() > 0 and login_text.first.is_visible()
    except Exception:
        return False
