creator=$1
acct=$2
pubkey=$3
fucli -u $turl system newaccount $creator $acct $pubkey --fund-account "5.00000000 FLON" -p $creator
