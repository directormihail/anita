from __future__ import annotations

import time
from datetime import datetime

from playwright.sync_api import sync_playwright

from .browser import is_login_page, launch_context, open_messages_page, save_storage_state
from .config import AppConfig


def run_interactive_login(config: AppConfig) -> None:
    print("Opening TikTok in a visible browser window.")
    print("Log in manually, then open your Messages inbox.")
    print("The app saves your session when it detects you are logged in.\n")

    with sync_playwright() as playwright:
        browser, context = launch_context(playwright, headless=False)
        page = context.new_page()

        try:
            open_messages_page(page, config.page_timeout_seconds * 1000)

            while True:
                if not is_login_page(page):
                    save_storage_state(context)
                    print("\nLogin saved. You can close this window.")
                    print("Next: python main.py test")
                    break

                print("Waiting for login...", end="\r")
                time.sleep(2)
        finally:
            context.close()
            browser.close()
