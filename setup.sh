#!/bin/bash

echo "🚀 در حال راه‌اندازی مانیتور ترافیک سرور..."

read -p "🪪 توکن ربات تلگرام را وارد کنید: " TELEGRAM_TOKEN
read -p "💬 آیدی چت (Chat ID) را وارد کنید: " CHAT_ID
read -p "🌐 نام اینترفیس شبکه (مثلاً eth0 یا ens3): " INTERFACE
read -p "📉 آستانه هشدار (MB): " THRESHOLD_MB
read -p "💻 نام سرور (مثلاً vps-paris): " SERVER_NAME

echo "📦 نصب ابزارهای لازم..."
apt update
apt install -y python3-full python3-venv curl

echo "🔧 ساخت محیط مجازی در /opt/traffic-monitor-venv"
python3 -m venv /opt/traffic-monitor-venv

echo "🐍 نصب کتابخانه python-telegram-bot..."
/opt/traffic-monitor-venv/bin/pip install --upgrade pip
/opt/traffic-monitor-venv/bin/pip install python-telegram-bot

echo "🧠 ساخت فایل پایتون با مقادیر وارد شده..."

cat <<EOF > /opt/traffic-monitor-venv/check_traffic_monitor.py
from telegram import Bot
import psutil
import socket
import datetime

TOKEN = "${TELEGRAM_TOKEN}"
CHAT_ID = "${CHAT_ID}"
INTERFACE = "${INTERFACE}"
THRESHOLD_MB = ${THRESHOLD_MB}
SERVER_NAME = "${SERVER_NAME}"

def send_message(message):
    bot = Bot(token=TOKEN)
    bot.send_message(chat_id=CHAT_ID, text=message)

def check_traffic():
    counters = psutil.net_io_counters(pernic=True)
    if INTERFACE not in counters:
        send_message(f"⚠️ Interface '{INTERFACE}' یافت نشد.")
        return

    data = counters[INTERFACE]
    used_mb = (data.bytes_sent + data.bytes_recv) / (1024 * 1024)
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    message = f"📡 [{SERVER_NAME}] ترافیک مصرفی در {timestamp}:\n🔻 مصرف کل: {used_mb:.2f} MB"
    if used_mb > THRESHOLD_MB:
        message += f"\n🚨 هشدار: مصرف بیش از {THRESHOLD_MB}MB!"
    send_message(message)

if __name__ == "__main__":
    check_traffic()
EOF

chmod +x /opt/traffic-monitor-venv/check_traffic_monitor.py

echo "🔁 ساخت سرویس و تایمر systemd..."

cat <<EOF > /etc/systemd/system/traffic-monitor.service
[Unit]
Description=Traffic Monitor Script
After=network.target

[Service]
Type=simple
ExecStart=/opt/traffic-monitor-venv/bin/python /opt/traffic-monitor-venv/check_traffic_monitor.py
EOF

cat <<EOF > /etc/systemd/system/traffic-monitor.timer
[Unit]
Description=Run Traffic Monitor every 60 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=60min
Unit=traffic-monitor.service

[Install]
WantedBy=timers.target
EOF

echo "♻️ ری‌لود systemd و فعال‌سازی تایمر..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now traffic-monitor.timer

echo "✅ مانیتور ترافیک با موفقیت نصب شد و هر ۶۰ دقیقه اجرا می‌شود."
echo "📨 اجرای تست اولیه..."
/opt/traffic-monitor-venv/bin/python /opt/traffic-monitor-venv/check_traffic_monitor.py
