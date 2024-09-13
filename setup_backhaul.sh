#!/bin/bash

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

# اگر سرور ایران باشد
if [ "$location" == "y" ]; then
    echo "این سرور ایران است، انجام تنظیمات برای ایران..."

    # دریافت تعداد سرورهای خارج
    read -p "چند سرور خارج دارید؟ " num_servers

    # حلقه برای هر سرور خارج
    for ((i=1; i<=num_servers; i++))
    do
        echo "در حال تنظیم سرور خارج شماره $i..."

        # دریافت اطلاعات سرور خارجی از کاربر
        read -p "شماره پورت تونل برای سرور خارج شماره $i را وارد کنید: " port

        # دریافت توکن برای سرور خارج
        read -p "لطفاً توکن برای سرور خارج شماره $i را وارد کنید: " token

        # دریافت مقدار mux_session برای سرور خارج
        read -p "لطفاً مقدار mux_session برای سرور خارج شماره $i را وارد کنید: " mux_session

        # انتخاب روش وارد کردن پورت‌ها برای این سرور
        read -p "آیا می‌خواهید پورت‌ها را دونه به دونه وارد کنید یا به صورت رنج (range)? (d/r): " method

        if [ "$method" == "d" ]; then
            # دریافت تعداد پورت‌های مورد نظر
            read -p "چند پورت برای تونل وجود دارد؟ " num_ports

            # ایجاد آرایه برای ذخیره پورت‌ها
            ports_list=()

            # دریافت پورت‌ها از کاربر و اضافه کردن به آرایه با دابل کوتیشن
            for ((j=1; j<=num_ports; j++))
            do
                read -p "لطفاً پورت شماره $j برای سرور خارج شماره $i را وارد کنید: " port_item
                ports_list+=("\"$port_item=$port_item\"")
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

        # ایجاد فایل پیکربندی برای سرور ایران با تنظیمات هر سرور خارج
        sudo tee /root/backhaul/config_$i.toml <<EOL
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

        # ایجاد فایل سرویس برای سرور خارج با شماره مشخص (i)
        sudo tee /etc/systemd/system/backhaul_$i.service <<EOL
[Unit]
Description=Backhaul Reverse Tunnel Service for Server $i
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/backhaul -c /root/backhaul/config_$i.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOL

        # فعال‌سازی و راه‌اندازی سرویس برای هر سرور با شماره i
        sudo systemctl daemon-reload
        sudo systemctl enable backhaul_$i.service
        sudo systemctl start backhaul_$i.service
    done

# اگر سرور خارج باشد
else
    echo "این سرور خارج است، انجام تنظیمات برای خارج..." 
 
    # دریافت آیپی ایران از کاربر
    read -p "لطفاً آیپی سرور ایران را وارد کنید: " ip_iran
 
    # دریافت شماره سرور خارجی که ست می‌شود
    read -p "این چندمین سرور خارجی است که روی سرور ایران ست می‌شود؟ " server_index
 
    # ایجاد فایل پیکربندی برای سرور خارج با شماره مشخص (server_index)
    sudo tee /root/backhaul/config_$server_index.toml <<EOL
[client]
remote_addr = "$ip_iran:$port" 
transport = "tcp"
token = "$token"
keepalive_period = 20
nodelay = false
retry_interval = 1
mux_session = $mux_session
EOL

    # ایجاد فایل سرویس برای سرور خارج با شماره مشخص (server_index)
    sudo tee /etc/systemd/system/backhaul_$server_index.service <<EOL
[Unit]
Description=Backhaul Reverse Tunnel Service for Server $server_index
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/backhaul -c /root/backhaul/config_$server_index.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOL

    # فعال‌سازی و راه‌اندازی سرویس برای این سرور خارج
    sudo systemctl daemon-reload
    sudo systemctl enable backhaul_$server_index.service
    sudo systemctl start backhaul_$server_index.service
fi

# ادامه دستورات مشترک
sudo systemctl daemon-reload
sudo systemctl status backhaul.service
