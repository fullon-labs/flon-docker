source ~/bin/.flontest.env

alias newt="fucli wallet create -f ~/.password.txt -n $twalname"
alias tacct="fucli -u $turl get account"
alias tcli="fucli -u $turl"
alias ttbl="fucli -u $turl get table"
alias ttran="fucli -u $turl transfer"
alias tpush="fucli -u $turl push action"
alias pki="fucli wallet import -n ${twalname} --private-key "
alias pkeys='fucli wallet private_keys -n ${twalname} --password "$(cat ~/.password.txt)" '

function plist() {
  fucli wallet private_keys -n ${twalname} --password "$(cat ~/.password.txt)" | grep -o '"5[A-Za-z0-9]*"' | tr -d '"'
}

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

function mreg() {
  echo "执行的测试链"
  treg "$@"
}

function treg() {
  local creator="$1"
  local acct="$2"
  local auth="$3"

  if [[ -z "$creator" || -z "$acct" ]]; then
    echo "❌ 用法: treg <creator> <new_account> [pubkey | account | account@perm]"
    return 1
  fi

  # 如果账号已存在则跳过
  if mcli get account "$acct" &>/dev/null; then
    echo "⚠️ 账号 [$acct] 已存在，跳过"
    return 0
  fi

  # 判断 auth 的格式
  if [[ -z "$auth" ]]; then
    auth="FU6Dm6xR3JxpeEhdswTV4qTawYXjBcV4gtWjRPELaS9wbQzNmSUC"  # 默认公钥
  elif [[ "$auth" =~ ^[a-z1-5.]+@[a-z]+$ ]]; then
    # 已经是 account@perm 格式，保留原样
    :
  elif mcli get account "$auth" &>/dev/null; then
    # 是账户名，默认用 @active 权限
    auth="${auth}@active"
  fi

  echo "🚀 创建账号 [$acct]，由 [$creator] 创建，授权 [$auth]"
  mcli system newaccount "$creator" "$acct" "$auth" \
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


alias mcli='echo "执行的测试链" && tcli'
alias mtran='echo "执行的测试链" && ttran'
alias mpush='echo "执行的测试链" && tpush'
alias um='echo "执行的测试链" && ut'

echo "turl is: $turl"
