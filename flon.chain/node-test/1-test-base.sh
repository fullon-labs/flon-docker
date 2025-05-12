#!/bin/bash

# 设置 tcli 命令别名
tcli="fucli --url http://hk-t3.vmi.nestar.vip:28888"

# 设置私钥和公钥
PrivKey="5JVLMtELdeV9F8woaswSGgwW4PvgLanrQXTcFcoPS4hoMJ8HPFB"
PubKey="FU642pEyHQXNz7FfUfHw7YF4Affnba2u8yCnYDVTT3K6hFJf5cWa"

# 定义账户名
MainAccount="flon"
GasAccount="flon.gas"
TestUser1="flon.test1"
TestUser2="flon.test2"

# 检查链信息
echo "🔍 获取区块链信息..."
$tcli get info || { echo "❌ 获取区块链信息失败"; exit 1; }

# 定义初始化函数
init() {
    echo "🔑 导入私钥..."
    $tcli wallet import --private-key "$PrivKey" || { echo "❌ 私钥导入失败"; exit 1; }

    $tcli create account $MainAccount $GasAccount $PubKey $PubKey || { echo "❌ Gas 账户创建失败"; exit 1; }
    $tcli create account $MainAccount $TestUser1 $PubKey $PubKey || { echo "❌ 测试账户创建失败"; exit 1; }
    $tcli create account $MainAccount $TestUser2 $PubKey $PubKey || { echo "❌ 测试账户创建失败"; exit 1; }

    echo "✅ 账户初始化完成！"
}

init

$tcli transfer $MainAccount $TestUser1 "100 FLON"
$tcli transfer $MainAccount $TestUser2 "100 FLON"

$tcli get currency balance flon.token $MainAccount