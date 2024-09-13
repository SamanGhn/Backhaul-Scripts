#!/bin/bash

# ایجاد فایل سرویس برای backhaul
echo "[Unit]
Description=Backhaul Reverse Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/backhaul -c /root/backhaul/config.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/backhaul.service

# دستورات اولیه برای نصب backhaul
mkdir -p backhaul
cd backhaul

wget https://github.com/Musixal/Backhaul/releases/download/v0.1.1/backhaul_linux_amd64.tar.gz -O backhaul_linux.tar.gz
tar -xf backhaul_linux.tar.gz
rm backhaul_linux.tar.gz LICENSE README.md
chmod +x backhaul
mv backhaul /usr/bin/backhaul

# بازگشت به دایرکتوری قبلی
cd ..

# دریافت موقعیت سرور از کاربر
read -p "آیا این سرور ایران است؟ (y/n): " location 

# دریافت پورت از کاربر
read -p "لطفاً شماره پورت تونل را وارد کنید: " port 

# دریافت توکن از کاربر
read -p "لطفاً توکن را وارد کنید: " token 

# دریافت مقدار mux_session از کاربر
read -p "لطفاً مقدار mux_session را وارد کنید: " mux_session

# بر اساس پاسخ کاربر دستورات مختلف را اجرا کنید
if [ "$location" == "y" ]; then
    echo "این سرور ایران است، انجام تنظیمات برای ایران..." 

    # انتخاب روش وارد کردن پورت‌ها
    read -p "آیا می‌خواهید پورت‌ها را دونه به دونه وارد کنید یا به صورت رنج (range)? (d/r): " method

    if [ "$method" == "d" ]; then
        # دریافت تعداد پورت‌های مورد نظر
        read -p "چند پورت برای تونل‌ها وجود دارد؟ " num_ports

        # ایجاد آرایه برای ذخیره پورت‌ها
        ports_list=()

        # دریافت پورت‌ها از کاربر و اضافه کردن به آرایه با دابل کوتیشن
        for ((i=1; i<=num_ports; i++))
        do
            read -p "لطفاً پورت شماره $i را وارد کنید: " port
            ports_list+=("\"$port=$port\"")
        done

    elif [ "$method" == "r" ]; then
        # دریافت رنج پورت‌ها از کاربر
        read -p "لطفاً پورت شروع را وارد کنید: " start_port
        read -p "لطفاً پورت پایان را وارد کنید: " end_port

        # ایجاد آرایه برای ذخیره پورت‌ها
        ports_list=()

        # تولید پورت‌ها بر اساس رنج و اضافه کردن به آرایه با دابل کوتیشن
        for ((port=start_port; port<=end_port; port++))
        do
            ports_list+=("\"$port=$port\"")
        done

    else
        echo "روش وارد کردن نامعتبر است. لطفاً 'd' برای دونه به دونه یا 'r' برای رنج وارد کنید."
        exit 1
    fi

    # تبدیل آرایه به رشته‌ای با جداکننده‌های مناسب برای فایل پیکربندی
    ports_string=$(IFS=,; echo "${ports_list[*]}")

    # دستورات برای سرورهای ایران
    sudo tee /root/backhaul/config.toml <<EOL
[server]
bind_addr = "0.0.0.0:$port"
transport = "tcp"
token = "$token"
keepalive_period = 20
nodelay = false
channel_size = 2048
connection_pool = 8
mux_session = $mux_session

ports = [ 
$ports_string
]
EOL

else
    echo "این سرور خارج است، انجام تنظیمات برای خارج..." 
 
    # دریافت آیپی ایران از کاربر
    read -p "لطفاً آیپی سرور ایران را وارد کنید: " ip_iran
 
    # دستورات برای سرورهای خارج
    sudo tee /root/backhaul/config.toml <<EOL
[client]
remote_addr = "$ip_iran:$port" 
transport = "tcp"
token = "$token"
keepalive_period = 20
nodelay = false
retry_interval = 1
mux_session = $mux_session
EOL
fi

# ادامه دستورات مشترک
sudo systemctl daemon-reload
sudo systemctl enable backhaul.service
sudo systemctl start backhaul.service
sudo systemctl status backhaul.service
