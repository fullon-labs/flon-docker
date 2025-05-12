# echo "all done..." && exit 0
# ssh -L 8888:127.0.0.1:28888 -C -N sh-node.flon.dev -p 19888 &
flonOwnerPubKey=AM5SMw8Lum7MG9V61LQz8enJyM9MB7WBpvoiXsp5YmAJXZmE92j2
flonActivePubKey=AM5SMw8Lum7MG9V61LQz8enJyM9MB7WBpvoiXsp5YmAJXZmE92j2
sys_accounts=(
    'flon.msig'
    'flon.names'
    'flon.stake'
    'flon.token'
    'cnyd.token'
)
user_accounts=(
)
contracts=(
    'flon flon.system'
    'flon.msig flon.msig'
    'cnyd.token flon.xtoken'
)
reserved_accounts=(

)

## This is to run locally

echo "### 1. unlock wallet"
# fucli wallet unlock -n flon-core

source .env

# echo "## 1. set active key for `flon` (skip - TODO)#
# flon set account permission ${contract} active --add-code

echo "## Create system accounts..."
for acct_info in "${sys_accounts[@]}"; do
  IFS=' ' read -r -a acct_array <<< "$acct_info"
  acct=${acct_array[0]}
  acctActiveKey="${acct_array[1]}"
  # echo "pub_key --> $acctActiveKey"
  fucli create account flon $acct $flonOwnerPubKey $acctActiveKey -p flon@active
  sleep 1
done
echo "....finishing creating system accounts..." && sleep 3

echo "## Create user accounts..."
for acct_info in "${user_accounts[@]}"; do
  IFS=' ' read -r -a array <<< "$acct_info"
  acct=${array[0]}
  acctActiveKey="${array[1]}"
  fucli create account flon $acct $acctActiveKey -p flon@active
  sleep 1
done
echo "....finishing creating user accounts..." && sleep 3

bash ./set_flon.token.sh

BOOTSTRAP_DIR=../../../bootstrap
echo "enable features..."
bash $BOOTSTRAP_DIR/bin/enable_features.sh
echo "finishing enabling features..." & sleep 3

for contract_info in "${contracts[@]}"; do
  IFS=' ' read -r -a array <<< "$contract_info"
  acct=${array[0]}
  contract="${array[1]}"
  echo "# Deploy contract: $contract"
  fucli set contract $acct $BOOTSTRAP_DIR/$contract -p $acct@active
  echo "finishing deploying $cct..." & sleep 3
done

echo "init flon.system..."
fucli push action flon init '[0, "8,flon"]' -p flon@active
echo "finishing init flon"
sleep 3

echo "Designate flon.msig as privileged account"
fucli push action flon setpriv '["flon.msig", 1]' -p flon@active
echo "finished setpriv...final step!!!"
sleep 1
echo
echo
echo "Congrats for flon mainnet launch!!!"

echo
echo "check flon.token accounts...."
## check accounts
fucli get table flon.token flon accounts