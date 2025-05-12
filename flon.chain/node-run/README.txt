#create new node
cp conf.env ~/
cp testnet/conf.bp.env ~/
modify conf.env & conf.bp.env
./1-setup-node-env.sh
cd ~/.XXXX
./run.sh

#reset node
node=XXXX
docker stop $node & docker rm $node
