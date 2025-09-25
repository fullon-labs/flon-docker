chmod +x deploy-eos-k8s.sh
./deploy-eos-k8s.sh install --namespace eos --storage-class fast-ssd --pvc-size 1Ti --peers "peer1.example.com:9876,peer2.example.com:9876"


./deploy-eos-k8s.sh install --snapshot-url https://your-bucket/snapshots/eos-snap-123456.bin.zst

./deploy-eos-k8s.sh install --ingress-host eos-rpc.yourdomain.com


./deploy-eos-k8s.sh install --producer \
  --producer-name yourbpname \
  --signature-provider "EOS6....=KEOSD:PW5K...." \
  --peers "bp1:9876,bp2:9876"


./deploy-eos-k8s.sh status
./deploy-eos-k8s.sh logs