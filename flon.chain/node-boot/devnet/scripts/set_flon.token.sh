BOOTSTRAP_DIR=../../../bootstrap

echo "# Deploy flon.token contract"
fucli set contract flon.token $BOOTSTRAP_DIR/flon.token/ -p flon.token@active
echo "....finishing deploying..." && sleep 3

echo "## Create and allocate the SYS currency = flon"
fucli push action flon.token create '[ "flon", "1000000000.00000000 flon" ]' -p flon.token@active
echo "....finishing creating 1 bn flon" && sleep 3

## issue 0.9 bn
fucli push action flon.token issue  '[ "flon", "900000000.00000000 flon", "" ]' -p flon@active
sleep 1
echo "....finishing issue 0.9 bn flon"
