#!/bin/bash

# تنظیمات ابتدایی
set -e  # متوقف کردن اجرای اسکریپت در صورت بروز خطا

# آدرس مخزن GitHub
REPO_URL="https://github.com/SamanGhn/Backhaul-Scripts/raw/main/setup_backhaul.sh"
SCRIPT_NAME="setup_backhaul.sh"

# دانلود فایل اسکریپت از GitHub
echo "دانلود فایل اسکریپت از GitHub..."
curl -L "$REPO_URL" -o "$SCRIPT_NAME"

# تغییر مجوز فایل برای اجرا
chmod +x "$SCRIPT_NAME"

# اجرای اسکریپت
echo "اجرای فایل اسکریپت..."
./"$SCRIPT_NAME"
