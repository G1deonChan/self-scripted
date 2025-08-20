#!/bin/bash

# 简化版SSH密钥管理脚本 - 用于调试
# 测试交互功能

echo "=== SSH密钥管理工具 - 调试版 ==="
echo "正在测试交互功能..."

# 测试基本输入
echo -n "请输入任意字符进行测试: "
read test_input
echo "您输入了: $test_input"

# 测试选择菜单
while true; do
    echo ""
    echo "请选择操作："
    echo "1) 添加SSH公钥"
    echo "2) 查看现有公钥" 
    echo "3) 退出"
    echo ""
    
    # 使用不同的输入方式
    printf "请选择 [1-3]: "
    read -r choice
    
    case $choice in
        1)
            echo "您选择了添加SSH公钥"
            echo -n "请输入SSH公钥: "
            read -r ssh_key
            echo "收到公钥: $ssh_key"
            ;;
        2)
            echo "显示现有公钥功能"
            if [ -f ~/.ssh/authorized_keys ]; then
                echo "当前公钥:"
                cat ~/.ssh/authorized_keys
            else
                echo "没有找到公钥文件"
            fi
            ;;
        3)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效选择: $choice"
            ;;
    esac
    
    echo -n "按回车键继续..."
    read
done
