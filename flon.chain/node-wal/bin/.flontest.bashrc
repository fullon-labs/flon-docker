source ~/bin/.flontest.env

alias newt="fucli wallet create -f ~/.password.txt -n $twalname"
alias tacct="fucli -u $turl get account"
alias tcli="fucli -u $turl"
alias ttbl="fucli -u $turl get table"
alias ttran="fucli -u $turl transfer"
alias tpush="fucli -u $turl push action"
alias pki="fucli wallet import -n ${twalname} --private-key "

function ut() {
    if [ ! -f ~/.password.txt ]; then
        echo "❌ ~/.password.txt not found"
        return 1
    fi
    if [ -z "$twalname" ]; then
        echo "❌ Environment variable 'twalname' is not set"
        return 1
    fi
    fucli wallet unlock -n "$twalname" --password "$(cat ~/.password.txt)"
}

function generate_key_pair() {
  local result
  result=$(tcli create key --to-console)

  echo "🔑 Key pair created:"
  echo "$result"

  privKey=$(echo "$result" | grep "Private key:" | awk '{print $3}')
  pubKey=$(echo "$result" | grep "Public key:" | awk '{print $3}')

  pki ${privKey}

  echo "✅ Private Key: $privKey"
  echo "✅ Public  Key: $pubKey"

  # 函数输出 pubKey，同时 privKey 设置为全局变量
  echo "$pubKey"
}



function treg() {
  local creator="$1"
  local acct="$2"
  local pubkey="$3"

  if [[ -z "$creator" || -z "$acct" || -z "$pubkey" ]]; then
    echo "❌ 用法: create_flon_account <creator> <new_account> <pubkey>"
    return 1
  fi

  echo "🚀 正在创建账号 [$acct]，由 [$creator] 创建，使用公钥 [$pubkey]"
  fucli -u "$turl" system newaccount "$creator" "$acct" "$pubkey" \
    --fund-account "5.00000000 FLON" -p "$creator"
}

function tnew() {

  local name="$1"
  local creator="flon"

  if [[ -z "$name" ]]; then
    echo "❌ 用法: tnew <account_name>"
    return 1
  fi

  echo "🔧 开始生成密钥对..."
  local ret
  ret=$(tcli create key --to-console)

  if [[ -z "$ret" ]]; then
    echo "❌ 密钥生成失败"
    return 1
  fi

  local privKey pubKey
  privKey=$(echo "$ret" | grep "Private key" | awk '{print $3}')
  pubKey=$(echo "$ret" | grep "Public key" | awk '{print $3}')

  echo "🔐 Private Key: $privKey"
  echo "🔓 Public  Key: $pubKey"

  echo "📥 导入私钥到钱包..."
  pki "$privKey"

  echo "🚀 正在注册账户 [$name]..."
  treg "$creator" "$name" "$pubKey"
}

tset() {
  local con="$1"
  local condir="$2"

  if [[ -z "$con" || -z "$condir" ]]; then
    echo "❌ 用法: tset <contract_account> <contract_dir>"
    return 1
  fi

  local path="./build/contracts/$condir"
  if [[ ! -d "$path" ]]; then
    echo "❌ 合约目录不存在: $path"
    return 1
  fi

  echo "🚀 正在将合约 [$condir] 部署到账号 [$con]..."
  fucli -u "$turl" set contract "$con" "$path" -p "${con}@active"
}


echo "turl is: $turl"
