#!/bin/bash


FUNOD_URL=$1

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FLON_PUBKEY=${FLON_PUBKEY:-"FU55xnsNNRaHqyRFZ4aYMEb6vVXw8eZWZYBt9kBX3xgBaeRwJFVV"}
FLON_PRIVKEY=${FLON_PRIVKEY:-"5K4Bjy3ZWUUUrTbUKANcx13fgY3kXWUDtwYTDQhu7v1ALvrmAAK"}
FUNOD_URL=${FUNOD_URL:-"http://127.0.0.1:28888"}
TOTAL_VOTE_STAKES=${TOTAL_VOTE_STAKES:-"100000000.00000000"}
PRODUCER_LIMIT=${PRODUCER_LIMIT:-0}
VOTER_LIMIT=${VOTER_LIMIT:-0}
CONTRACTS_DIR=${CONTRACTS_DIR:-"${CUR_DIR}/../contracts"}
UPDATE_APT_SOURCES_LIST=${UPDATE_APT_SOURCES_LIST:-true}
INSTALL_DEPENDENCE_LIB=${INSTALL_DEPENDENCE_LIB:-true}

if [ -f ${CUR_DIR}/.env ]; then
  source ${CUR_DIR}/.env
fi

echo "- Using CONTRACTS_DIR=${CONTRACTS_DIR}"

if [[ ${UPDATE_APT_SOURCES_LIST} == true ]]; then
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list
fi

# export COLOR_NC=$(tput sgr0) # No Color
# export COLOR_RED=$(tput setaf 1)
# export COLOR_GREEN=$(tput setaf 2)
# export COLOR_YELLOW=$(tput setaf 3)

which fucli ||  ( echo "${COLOR_RED}fucli command not found!${COLOR_NC}" && exit 1 )

if [[ ${INSTALL_DEPENDENCE_LIB} == true ]]; then
    # Detect OS and install necessary packages
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    elif [ -f /etc/centos-release ]; then
        OS=centos
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi

    case $OS in
        ubuntu|debian)
            dpkg --status python3-pip > /dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                apt update
                apt install -y python3 python3-pip
            fi
            ;;
        centos|rhel|fedora)
            rpm -q python3-pip > /dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                yum install -y python3 python3-pip
            fi
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac

    pip3 show numpy || pip3 install numpy
    pip3 show requests || pip3 install requests
    pip3 show eth_keys || pip3 install eth_keys
    pip3 show aioeos || pip3 install aioeos
    pip3 show pycryptodome || pip3 install pycryptodome
    pip3 show pysha3 || pip3 install pysha3
fi

python3 ${CUR_DIR}/init.chain.py \
    --log-path=/tmp/run.init.chain.log \
    --account-path="${CUR_DIR}/conf/accounts.json" \
    --contracts-dir="${CONTRACTS_DIR}" \
    --wallet-dir="${CUR_DIR}/.wallet" \
    --url="${FUNOD_URL}" \
    --public-key="${FLON_PUBKEY}" --private-key="${FLON_PRIVKEY}" \
    --wallet \
    --producer-limit=${PRODUCER_LIMIT} \
    --voter-limit=${VOTER_LIMIT} \
    --total-vote-stakes=${TOTAL_VOTE_STAKES} \
    --sys \
    --features \
    --contracts \
    --tokens \
    --sys-contract \
    --init-sys-contract
    # --reg-accounts
    # --vote

# TODO:
    # --init-evm-contract
    # --reg-accounts
    # --vote

[[ $? -ne 0 ]] && echo "${COLOR_RED}Execute init.chain.py failed${COLOR_NC}"

sleep 3