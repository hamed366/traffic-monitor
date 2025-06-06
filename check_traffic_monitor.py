import os
import asyncio
import psutil
import httpx
from telegram import Bot
from telegram.request import HTTPXRequest

# گرفتن متغیرهای محیطی
TOKEN = os.getenv("BOT_TOKEN")
CHAT_ID = os.getenv("CHAT_ID")
INTERFACE = os.getenv("INTERFACE", "eth0")
THRESHOLD_GB = float(os.getenv("THRESHOLD_GB", 100))
SERVER_NAME = os.getenv("SERVER_NAME", "MyServer")
PROXY = os.getenv("PROXY", "socks5://127.0.0.1:1080")

# ساخت بات فقط داخل تابع async
async def send_message(message: str):
    async with httpx.AsyncClient(proxies=PROXY) as client:
        request = HTTPXRequest(client=client)
        bot = Bot(token=TOKEN, request=request)
        await bot.send_message(chat_id=CHAT_ID, text=message)

async def check_traffic():
    rx_path = f"/sys/class/net/{INTERFACE}/statistics/rx_bytes"
    tx_path = f"/sys/class/net/{INTERFACE}/statistics/tx_bytes"

    try:
        with open(rx_path, "r") as f:
            rx_bytes = int(f.read())
        with open(tx_path, "r") as f:
            tx_bytes = int(f.read())
    except FileNotFoundError:
        await send_message(f"⚠️ Interface '{INTERFACE}' یافت نشد.")
        return

    total_gb = (rx_bytes + tx_bytes) / (1024 ** 3)
    if total_gb >= THRESHOLD_GB:
        await send_message(
            f"📶 سرور {SERVER_NAME} به سقف تعیین‌شده رسید.\n"
            f"🌐 Interface: {INTERFACE}\n"
            f"📊 مصرف: {total_gb:.2f} GB از {THRESHOLD_GB} GB"
        )

if __name__ == "__main__":
    asyncio.run(check_traffic())

