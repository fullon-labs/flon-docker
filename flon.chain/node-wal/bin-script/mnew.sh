#!/bin/bash

shopt -s expand_aliases
source ~/.bashrc

name=$1
creator=flon

um

ret=`mcli create key --to-console`
echo "create key: $ret"
privKey=${ret:13:51}
pubKey=`echo $ret | sed -n '1p'`
pubKey=${pubKey:0-52:52}
echo "privKey: $privKey"
echo "pubKey: $pubKey"
mpki ${privKey}

mreg $creator $name $pubKey