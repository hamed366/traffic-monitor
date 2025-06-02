#!/bin/bash

echo "🔧 در حال راه‌اندازی مانیتور ترافیک اینترنت سرور..."

# دریافت ورودی‌های کاربر
read -p "🟡 توکن ربات تلگرام: " TELEGRAM_TOKEN
read -p "🟡 آیدی چت تلگرام: " CHAT_ID
read -p "🟡 نام سرور (مثلاً 'فرانت هنگ‌کنگ'): " SERVER_NAME
read -p "🟡 نام اینترفیس شبکه (مثل ens5): " INTERFACE
read -p "🟡 آستانه هشدار حجم (گیگابایت): " THRESHOLD
read -p "🟡 هر چند دقیقه یکبار اجرا شود؟ " INTERVAL_MINUTES

# نصب پکیج‌ها
apt update
apt install -y python3 python3-pip vnstat
pip3 install python-telegram-bot==13.15 pytz

# تولید اسکریپت پایتون
cat <<EOF > /root/check_traffic_monitor.py
from telegram import Bot
import subprocess
import pytz
from datetime import datetime

TOKEN = "$TELEGRAM_TOKEN"
CHAT_ID = "$CHAT_ID"
INTERFACE = "$INTERFACE"
THRESHOLD_GB = $THRESHOLD
SERVER_NAME = "$SERVER_NAME"

def convert_to_gb(text):
    num, unit = float(text.split()[0]), text.split()[1]
    factor = {"KiB": 1/1048576, "MiB": 1/1024, "GiB": 1, "TiB": 1024}
    return round(num * factor.get(unit, 0), 2)

def main():
    try:
        result = subprocess.check_output(["vnstat", "-i", INTERFACE, "--oneline"]).decode()
        fields = result.strip().split(";")
        if len(fields) < 15:
            raise ValueError(f"خروجی vnstat ناکامل است. تعداد فیلدها: {len(fields)}")

        today_total = convert_to_gb(fields[5])
        total_traffic = convert_to_gb(fields[14])

        timezone = pytz.timezone("Asia/Shanghai")
        now = datetime.now(timezone).strftime("%Y-%m-%d %H:%M:%S")

        msg = f"📡 حجم مصرفی سرور {SERVER_NAME}\n\n"
        msg += f"📅 {now}\n"
        msg += f"🔹 مصرف امروز تا این لحظه: {today_total} گیگابایت\n"
        msg += f"🔸 مجموع مصرف کلی از ابتدا: {total_traffic} گیگابایت\n"

        if total_traffic >= THRESHOLD_GB:
            msg += f"\n🚨 هشدار: مصرف کلی از آستانه {THRESHOLD_GB} گیگابایت بیشتر شده است!"

        bot = Bot(token=TOKEN)
        bot.send_message(chat_id=CHAT_ID, text=msg)

    except Exception as e:
        bot = Bot(token=TOKEN)
        bot.send_message(chat_id=CHAT_ID, text=f"❌ خطا در بررسی ترافیک:\n{str(e)}")

if __name__ == "__main__":
    main()
EOF

# ساخت فایل‌های systemd
cat <<EOF > /etc/systemd/system/traffic-monitor.service
[Unit]
Description=Traffic Monitor Script

[Service]
ExecStart=/usr/bin/python3 /root/check_traffic_monitor.py
EOF

cat <<EOF > /etc/systemd/system/traffic-monitor.timer
[Unit]
Description=Run traffic monitor every ${INTERVAL_MINUTES} minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=${INTERVAL_MINUTES}min
Unit=traffic-monitor.service

[Install]
WantedBy=timers.target
EOF

# فعال‌سازی تایمر
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now traffic-monitor.timer

echo "✅ مانیتور ترافیک هر ${INTERVAL_MINUTES} دقیقه اجرا خواهد شد."
echo "📨 ارسال پیام تستی..."

# اجرای تستی
python3 /root/check_traffic_monitor.py
