from telegram import Bot
import psutil
import socket
import datetime
import asyncio

TOKEN = "YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID = "YOUR_CHAT_ID"
INTERFACE = "YOUR_NETWORK_INTERFACE"
THRESHOLD_MB = 500
SERVER_NAME = "YOUR_SERVER_NAME"

async def send_message(message):
    bot = Bot(token=TOKEN)
    await bot.send_message(chat_id=CHAT_ID, text=message)

async def check_traffic():
    counters = psutil.net_io_counters(pernic=True)
    if INTERFACE not in counters:
        await send_message(f"⚠️ Interface '{INTERFACE}' یافت نشد.")
        return

    data = counters[INTERFACE]
    used_mb = (data.bytes_sent + data.bytes_recv) / (1024 * 1024)
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    message = f"📡 [{SERVER_NAME}] ترافیک مصرفی در {timestamp}:\n🔻 مصرف کل: {used_mb:.2f} MB"
    if used_mb > THRESHOLD_MB:
        message += f"\n🚨 هشدار: مصرف بیش از {THRESHOLD_MB}MB!"
    await send_message(message)

if __name__ == "__main__":
    asyncio.run(check_traffic())
