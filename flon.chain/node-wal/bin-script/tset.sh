con=$1
condir=$2

fucli -u $turl set contract $con ./build/contracts/$condir -p ${con}@active
