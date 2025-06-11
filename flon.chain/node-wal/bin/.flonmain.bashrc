source ~/bin/.flonmain.env

alias newm="fucli wallet create -f ~/.main_password.txt -n $mwalname"
alias macct="fucli -u $murl get account"
alias mcli="fucli -u $murl"
alias mtbl="fucli -u $murl get table"
alias mtran="fucli -u $murl transfer"
alias mpush="fucli -u $murl push action"
alias mpki="fucli wallet import -n ${mwalname} --private-key "
function um() {
    if [ ! -f ~/.main_password.txt ]; then
        echo "❌ ~/.main_password.txt not found"
        return 1
    fi
    if [ -z "$mwalname" ]; then
        echo "❌ Environment variable 'mwalname' is not set"
        return 1
    fi
    fucli wallet unlock -n "$mwalname" --password "$(cat ~/.main_password.txt)"
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
  local creator="$1"
  local acct="$2"
  local input="$3"

  if [[ -z "$creator" || -z "$acct" || -z "$input" ]]; then
    echo "❌ 用法: mreg <creator> <new_account> <pubkey | account | account@perm>"
    return 1
  fi

  # 跳过已存在账号
  if fucli -u "$murl" get account "$acct" &>/dev/null; then
    echo "⚠️ 账号 [$acct] 已存在，跳过"
    return 0
  fi

  # 判断 input 类型：是公钥、权限格式、还是账户名
  local auth="$input"
  if [[ "$input" =~ ^[a-z1-5.]+@[a-z]+$ ]]; then
    # 格式为 account@perm，保留原样
    :
  elif fucli -u "$murl" get account "$input" &>/dev/null; then
    # 是一个账户名，转为权限格式
    auth="${input}@owner"
  fi

  echo "🚀 创建账号 [$acct] by [$creator] with auth [$auth]"

  fucli -u "$murl" system newaccount "$creator" "$acct" "$auth" \
    --fund-account "0.00300000 FLON" -p "$creator"
}

function mnew() {
  local name="$1"
  local creator="flon"

  if [ -z "$name" ]; then
    echo "❌ 请输入账号名作为参数，例如：create_eos_account myaccount123"
    return 1
  fi

  echo "🔐 正在为账号 [$name] 生成密钥..."
  local ret
  ret=$(mcli create key --to-console)

  if [ -z "$ret" ]; then
    echo "❌ 密钥生成失败"
    return 1
  fi

  echo "🆗 create key: $ret"

  local privKey pubKey

  privKey=$(echo "$ret" | grep "Private key:" | awk '{print $3}')
  pubKey=$(echo "$ret" | grep "Public key:" | awk '{print $3}')

  echo "🔑 Private Key: $privKey"
  echo "🔓 Public  Key: $pubKey"

  echo "📥 导入私钥到钱包..."
  mpki "$privKey"

  echo "📝 正在注册账号 [$name] 到创建者 [$creator]..."
  mreg "$creator" "$name" "$pubKey"
}

function mset() {
  local con="$1"
  local condir="$2"

  if [[ -z "$con" || -z "$condir" ]]; then
    echo "❌ 用法: mset <account> <contract_dir>"
    return 1
  fi

  local contract_path="./build/contracts/$condir"

  if [[ ! -d "$contract_path" ]]; then
    echo "❌ 合约目录不存在: $contract_path"
    return 1
  fi

  echo "🚀 部署合约 [$condir] 到账户 [$con] ..."
  fucli -u "$murl" set contract "$con" "$contract_path" -p "${con}@active"
}



echo "murl is: $murl"