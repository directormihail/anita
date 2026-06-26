from __future__ import annotations

import re
import time
from datetime import datetime

from playwright.sync_api import Page, TimeoutError as PlaywrightTimeoutError

from .browser import is_login_page, open_messages_page, save_storage_state
from .config import AppConfig


def _normalize_name(value: str) -> str:
    return re.sub(r"^@", "", value.strip()).lower()


def open_friend_chat(page: Page, friend_name: str, timeout_ms: int) -> None:
    target = _normalize_name(friend_name)
    deadline = time.time() + (timeout_ms / 1000)

    while time.time() < deadline:
        candidates = page.locator(
            '[data-e2e="chat-list-item"], [class*="ChatList"], a[href*="/messages"]'
        )
        count = candidates.count()
        for index in range(count):
            item = candidates.nth(index)
            try:
                text = item.inner_text(timeout=1000).lower()
            except PlaywrightTimeoutError:
                continue

            if target in text:
                item.click()
                page.wait_for_timeout(1500)
                return

        # Fallback: click any element that visibly contains the friend's name.
        fallback = page.get_by_text(friend_name, exact=False)
        if fallback.count() > 0:
            fallback.first.click()
            page.wait_for_timeout(1500)
            return

        page.wait_for_timeout(1000)

    raise RuntimeError(
        f"Could not find a DM conversation for '{friend_name}'. "
        "Open TikTok messages once manually and make sure the chat exists."
    )


def _focus_message_editor(page: Page) -> None:
    selectors = [
        '[contenteditable="true"]',
        '[data-e2e="message-input-area"] [contenteditable="true"]',
        'div[role="textbox"]',
        'textarea',
    ]

    for selector in selectors:
        locator = page.locator(selector).last
        if locator.count() == 0:
            continue
        try:
            locator.click(timeout=3000)
            page.wait_for_timeout(300)
            return
        except PlaywrightTimeoutError:
            continue

    raise RuntimeError("Could not find the TikTok message input box.")


def _type_draftjs_message(page: Page, message: str) -> None:
    """TikTok chat uses Draft.js; keyboard insert works better than fill()."""
    _focus_message_editor(page)

    page.keyboard.press("ControlOrMeta+A")
    page.keyboard.press("Backspace")
    page.keyboard.insert_text(message)
    page.wait_for_timeout(400)

    # Clipboard injection fallback if insert_text did not stick.
    inserted = page.evaluate(
        """
        (text) => {
            const editor = document.querySelector('[contenteditable="true"]');
            if (!editor) return false;
            return (editor.innerText || '').trim() === text.trim();
        }
        """,
        message,
    )
    if inserted:
        return

    page.evaluate(
        """
        (text) => {
            const editor = document.querySelector('[contenteditable="true"]');
            if (!editor) return;

            editor.focus();
            const data = new DataTransfer();
            data.setData('text/plain', text);
            const pasteEvent = new ClipboardEvent('paste', {
                bubbles: true,
                cancelable: true,
                clipboardData: data,
            });
            editor.dispatchEvent(pasteEvent);
        }
        """,
        message,
    )
    page.wait_for_timeout(400)


def _submit_message(page: Page) -> None:
    send_selectors = [
        '[data-e2e="message-send"]',
        'button[type="submit"]',
        'button:has-text("Send")',
    ]

    for selector in send_selectors:
        button = page.locator(selector).last
        if button.count() == 0:
            continue
        try:
            if button.is_enabled():
                button.click(timeout=2000)
                page.wait_for_timeout(800)
                return
        except PlaywrightTimeoutError:
            continue

    page.keyboard.press("Enter")
    page.wait_for_timeout(800)


def send_hui_message(page: Page, config: AppConfig) -> None:
    timeout_ms = config.page_timeout_seconds * 1000

    open_messages_page(page, timeout_ms)

    if is_login_page(page):
        raise RuntimeError(
            "TikTok session expired or missing. Run: python main.py login"
        )

    open_friend_chat(page, config.friend_name, timeout_ms)
    _type_draftjs_message(page, config.message)
    _submit_message(page)


def send_daily_message(config: AppConfig, *, headless: bool | None = None) -> None:
    from playwright.sync_api import sync_playwright

    from .browser import launch_context

    use_headless = config.headless if headless is None else headless
    started = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{started}] Sending '{config.message}' to {config.friend_name}...")

    with sync_playwright() as playwright:
        browser, context = launch_context(playwright, headless=use_headless)
        page = context.new_page()
        try:
            send_hui_message(page, config)
            save_storage_state(context)
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Message sent.")
        finally:
            context.close()
            browser.close()
