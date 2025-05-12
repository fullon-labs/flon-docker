con=$1
condir=$2

fucli -u $murl set contract $con ./build/contracts/$condir -p ${con}@active
