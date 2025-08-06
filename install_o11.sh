#!/bin/bash

# 定义目标目录和程序名
INSTALL_DIR="/etc/o11"
EXECUTABLE="o11_v22b1-DRMStuff"
REPO_RAW_URL="https://raw.githubusercontent.com/DRMStuff/o11-OTT-v2.2b1/main/$EXECUTABLE"
SERVICE_FILE="/etc/systemd/system/o11.service"

# 创建目录
echo "创建目录 $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"

# 下载可执行文件
echo "从 GitHub 下载程序..."
sudo curl -L "$REPO_RAW_URL" -o "$INSTALL_DIR/$EXECUTABLE"
if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络或GitHub地址是否有效。"
    exit 1
fi

# 赋予执行权限
echo "设置执行权限..."
sudo chmod +x "$INSTALL_DIR/$EXECUTABLE"

# 创建 systemd 服务文件
echo "创建 systemd 服务..."
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=O11 DRMStuff Service
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$EXECUTABLE
Restart=always
RestartSec=3
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启动服务
echo "启用并启动服务..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable o11.service
sudo systemctl start o11.service

echo "安装完成，服务状态如下："
sudo systemctl status o11.service --no-pager
