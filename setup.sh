#!/bin/bash

echo "📦 نصب ابزارهای لازم..."
apt update
apt install -y python3-full python3-venv curl

echo "🔧 ساخت محیط مجازی..."
python3 -m venv /opt/traffic-monitor-venv

echo "🐍 نصب پکیج python-telegram-bot در محیط مجازی..."
/opt/traffic-monitor-venv/bin/pip install --upgrade pip
/opt/traffic-monitor-venv/bin/pip install python-telegram-bot

echo "📄 دریافت اسکریپت چک ترافیک..."
curl -s -o /opt/traffic-monitor-venv/check_traffic_monitor.py https://raw.githubusercontent.com/hamed366/traffic-monitor/main/check_traffic_monitor.py
chmod +x /opt/traffic-monitor-venv/check_traffic_monitor.py

echo "🛠 ساخت فایل systemd سرویس و تایمر..."

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

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now traffic-monitor.timer

echo "✅ مانیتور ترافیک هر 60 دقیقه اجرا خواهد شد."
echo "📨 ارسال پیام تستی..."

# اجرای تستی اولیه
/opt/traffic-monitor-venv/bin/python /opt/traffic-monitor-venv/check_traffic_monitor.py
