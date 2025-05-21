source ~/bin/.flontest.env

alias newt="fucli wallet create -f ~/.password.txt -n $twalname"
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



alias tacct="fucli -u $turl get account"
alias tcli="fucli -u $turl"
alias ttbl="fucli -u $turl get table"
alias ttran="fucli -u $turl transfer"
alias tpush="fucli -u $turl push action"
alias pki="fucli wallet import -n ${twalname} --private-key "
alias treg="bash ~/bin/treg.sh"
alias tset="bash ~/bin/tset.sh"
alias tnew="bash ~/bin/tnew.sh"
echo "turl is: $turl"
