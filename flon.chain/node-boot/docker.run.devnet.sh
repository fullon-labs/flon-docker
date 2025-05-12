# 检查参数
if [ $# -eq 0 ]; then
    echo "错误：缺少初始化参数 节点地址" 
    exit 1
fi

docker cp ./devnet fuwal:/root/
docker exec -it fuwal bash -c "cd ~/devnet && ./run.init.chain.sh \"$1\" && sleep 5 && exit"