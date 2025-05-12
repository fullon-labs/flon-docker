#!/usr/bin/env python3

import argparse
import json
import numpy
import os
import random
import re
import subprocess
import sys
import time
from datetime import timedelta
from datetime import datetime
import decimal
import requests
import eth_keys
import aioeos

args = None
logFile = None
accounts = {}

unlockTimeout = 999999999

systemAccounts = [
    'flon.bpay',
    'flon.msig',
    'flon.names',
    'flon.fees',
    'flon.stake',
    'flon.token',
    'flon.reward',
    'flon.vote',
    'flon.evm',
    'evm.miner'
]

def jsonArg(a):
    return " '" + json.dumps(a) + "' "

def run(args):
    print('init.chain.py:', args)
    logFile.write(args + '\n')
    if subprocess.call(args, shell=True):
        print('init.chain.py: exiting because of error')
        sys.exit(1)

def runStatus(args):
    print('init.chain.py:', args)
    logFile.write(args + '\n')
    return subprocess.call(args, shell=True)

def retry(args):
    count=3
    while True:
        count -= 1
        print('init.chain.py: ', args)
        logFile.write(args + '\n')
        if subprocess.call(args, shell=True):
            print('*** Retry')
        else:
            break
        if count == 0:
            sleep(3)
            count = 1

def background(args):
    print('init.chain.py:', args)
    logFile.write(args + '\n')
    return subprocess.Popen(args, shell=True)

def getOutput(args):
    print('init.chain.py:', args)
    logFile.write(args + '\n')
    proc = subprocess.Popen(args, shell=True, stdout=subprocess.PIPE)
    return proc.communicate()[0].decode('utf-8')

def getJsonOutput(args):
    return json.loads(getOutput(args))

def getRpc(url):
    print('init.chain.py: request rpc: ', url)
    res = requests.get(url)

    if res.status_code >= 200 and res.status_code < 300:
        return json.loads(res.content)
    else:
        print('init.chain.py: exiting because of error: ' + res.content)
        sys.exit(1)

def getAssetAmount(s):
    assert(isinstance(s, str))
    s = s.split()[0].replace(".", "")
    return int(decimal.Decimal(s))

def getTableRows(args, contract, scope, table):
    more = True
    nextKey = 0
    rows = []
    while(more):
        tableInfo = getJsonOutput(args.fucli + 'get table %s %s %s --limit 100 --index 1 -L %s' % (str(contract), str(scope), str(table), nextKey))
        rows = rows + tableInfo['rows']
        more = tableInfo['more']
        nextKey = tableInfo['next_key']
    return rows

def getTableRow(args, contract, scope, table, pk):
    pkStr = str(pk)
    tableInfo = getJsonOutput(args.fucli + 'get table %s %s %s --index 1 -L %s -U %s --key-type i64' % (str(contract), str(scope), str(table), pkStr, pkStr))
    if (len(tableInfo['rows']) > 0):
        return tableInfo['rows'][0]
    return None

def sleep(t):
    print('sleep', t, '...')
    time.sleep(t)
    print('resume')

def startWallet():
    run('killall fuwal || true')
    sleep(1.5)
    run('rm -rf ' + os.path.abspath(args.wallet_dir))
    run('mkdir -p ' + os.path.abspath(args.wallet_dir))
    background(args.fuwal + ' --unlock-timeout %d --http-server-address 127.0.0.1:6666 --wallet-dir %s' % (unlockTimeout, os.path.abspath(args.wallet_dir)))
    sleep(.4)
    run(args.fucli + 'wallet create --to-console')

def importKeys():
    run(args.fucli + 'wallet import --private-key ' + args.private_key)
    allAccounts = accounts['producers'] + accounts['voters']
    keys = {}
    for a in allAccounts:
        key = a['pvt']
        if not key in keys:
            keys[key] = True
            run(args.fucli + 'wallet import --private-key ' + key)

def createSystemAccounts():
    for a in systemAccounts:
        run(args.fucli + 'create account flon ' + a + ' ' + args.public_key)

def activateFeatures():

    retry('curl -X POST %s' % args.url +
        '/v1/producer/schedule_protocol_feature_activations ' +
        '-d \'{"protocol_features_to_activate": ["0ec7e080177b2c02b278d5088611686b49d739925a92d9bfcacd7fc6b74053bd"]}\'')
    sleep(3)

    # install flon.boot which supports the native actions and activate
    # action that allows activating desired protocol features prior to
    # deploying a system contract with more features such as flon.boot
    # or flon.system
    retry(args.fucli + 'set contract flon ' + args.contracts_dir + '/flon.boot/')
    sleep(3)



    # activate remaining features
    # ACTION_RETURN_VALUE
    retry(args.fucli + 'push action flon activate \'["c3a6138c5061cf291310887c0b5c71fcaffeab90d5deb50d3b9e687cead45071"]\' -p flon@active')
    # CONFIGURABLE_WASM_LIMITS2
    retry(args.fucli + 'push action flon activate \'["d528b9f6e9693f45ed277af93474fd473ce7d831dae2180cca35d907bd10cb40"]\' -p flon@active')
    # BLOCKCHAIN_PARAMETERS
    retry(args.fucli + 'push action flon activate \'["5443fcf88330c586bc0e5f3dee10e7f63c76c00249c87fe4fbf7f38c082006b4"]\' -p flon@active')
    # GET_SENDER
    retry(args.fucli + 'push action flon activate \'["f0af56d2c5a48d60a4a5b5c903edfb7db3a736a94ed589d0b797df33ff9d3e1d"]\' -p flon@active')
    #FURWARD_SETCODE
    retry(args.fucli + 'push action flon activate \'["2652f5f96006294109b3dd0bbde63693f55324af452b799ee137a81a905eed25"]\' -p flon@active')
    # ONLY_BILL_FIRST_AUTHORIZER
    retry(args.fucli + 'push action flon activate \'["8ba52fe7a3956c5cd3a656a3174b931d3bb2abb45578befc59f283ecd816a405"]\' -p flon@active')
    # RESTRICT_ACTION_TO_SELF
    retry(args.fucli + 'push action flon activate \'["ad9e3d8f650687709fd68f4b90b41f7d825a365b02c23a636cef88ac2ac00c43"]\' -p flon@active')
    # DISALLOW_EMPTY_PRODUCER_SCHEDULE
    retry(args.fucli + 'push action flon activate \'["68dcaa34c0517d19666e6b33add67351d8c5f69e999ca1e37931bc410a297428"]\' -p flon@active')
     # FIX_LINKAUTH_RESTRICTION
    retry(args.fucli + 'push action flon activate \'["e0fb64b1085cc5538970158d05a009c24e276fb94e1a0bf6a528b48fbc4ff526"]\' -p flon@active')
    ## REPLACE_DEFERRED
    #retry(args.fucli + 'push action flon activate \'["ef43112c6543b88db2283a2e077278c315ae2c84719a8b25f25cc88565fbea99"]\' -p flon@active')
    ## NO_DUPLICATE_DEFERRED_ID
    #retry(args.fucli + 'push action flon activate \'["4a90c00d55454dc5b059055ca213579c6ea856967712a56017487886a4d4cc0f"]\' -p flon@active')
    # ONLY_LINK_TO_EXISTING_PERMISSION
    retry(args.fucli + 'push action flon activate \'["1a99a59d87e06e09ec5b028a9cbb7749b4a5ad8819004365d02dc4379a8b7241"]\' -p flon@active')
    # RAM_RESTRICTIONS
    retry(args.fucli + 'push action flon activate \'["4e7bf348da00a945489b2a681749eb56f5de00b900014e137ddae39f48f69d67"]\' -p flon@active')
    # WEBAUTHN_KEY
    retry(args.fucli + 'push action flon activate \'["4fca8bd82bbd181e714e283f83e1b45d95ca5af40fb89ad3977b653c448f78c2"]\' -p flon@active')
    # WTMSIG_BLOCK_SIGNATURES
    retry(args.fucli + 'push action flon activate \'["299dcb6af692324b899b39f16d5a530a33062804e41f09dc97e9f156b4476707"]\' -p flon@active')
    # GET_CODE_HASH
    retry(args.fucli + 'push action flon activate \'["bcd2a26394b36614fd4894241d3c451ab0f6fd110958c3423073621a70826e99"]\' -p flon@active')
    # GET_BLOCK_NUM
    retry(args.fucli + 'push action flon activate \'["35c2186cc36f7bb4aeaf4487b36e57039ccf45a9136aa856a5d569ecca55ef2b"]\' -p flon@active')
    # CRYPTO_PRIMITIVES
    retry(args.fucli + 'push action flon activate \'["6bcb40a24e49c26d0a60513b6aeb8551d264e4717f306b81a37a5afb3b47cedc"]\' -p flon@active')
    # BLS_PRIMITIVES2
    retry(args.fucli + 'push action flon activate \'["63320dd4a58212e4d32d1f58926b73ca33a247326c2a5e9fd39268d2384e011a"]\' -p flon@active')
    ## DISABLE_DEFERRED_TRXS_STAGE_1 - DISALLOW NEW DEFERRED TRANSACTIONS
    #retry(args.fucli + 'push action flon activate \'["fce57d2331667353a0eac6b4209b67b843a7262a848af0a49a6e2fa9f6584eb4"]\' -p flon@active')
    ## DISABLE_DEFERRED_TRXS_STAGE_2 - PREVENT PREVIOUSLY SCHEDULED DEFERRED TRANSACTIONS FROM REACHING OTHER NODE
    ## THIS DEPENDS ON DISABLE_DEFERRED_TRXS_STAGE_1
    #retry(args.fucli + 'push action flon activate \'["09e86cb0accf8d81c9e85d34bea4b925ae936626d00c984e4691186891f5bc16"]\' -p flon@active')
    # SAVANNA
    # Depends on all previous protocol features
    retry(args.fucli + 'push action flon activate \'["72df75c0bf7fce15d7b95d8565eba38ff58231789273d39c68693c3557d64c54"]\' -p flon@active')
    sleep(1)

def assetMulti():
    return 10**args.precision

def assetFormat():
    return '{:d}.{:0' + str(args.precision) + 'd} {:s}'

def intToCurrency(i):
    return assetFormat().format(i // assetMulti(), i % assetMulti(), args.symbol)

def voteAsset(i):
    return assetFormat().format(i // assetMulti(), i % assetMulti(), "VOTE")

def voteToStaked(i):
    return int( i )

def stakedToVote(i):
    return int(i)

def fundToCurrency(f):
    i = int(f * assetMulti())
    return intToCurrency(i)

def listProducers():
    run(args.fucli + 'system listproducers')

# def producerClaimRewards():
#     print('Wait %ss before producer claimRewards' % (args.producer_claim_prewait_time))
#     sleep(args.producer_claim_prewait_time)
#     rows = getTableRows(args, "flon", "flon", "producers")
#     times = []
#     for row in rows:
#         rewards = row['unclaimed_rewards']
#         if rewards and getAssetAmount(rewards) > 0:
#             ret = getJsonOutput(args.fucli + 'system claimrewards -j ' + row['owner'])
#             times.append(ret['processed']['elapsed'])
#     print('Elapsed time for producer claimrewards:', times)

# def voterClaimRewards():
#     rows = getTableRows(args, "flon.reward", "flon.reward", "producers")
#     prods = {}
#     for row in rows:
#         prods[row["owner"]] = decimal.Decimal(row["rewards_per_vote"])
#     rows = getTableRows(args, "flon.reward", "flon.reward", "voters")
#     times = []
#     for row in rows:
#         unclaimed_rewards = getAssetAmount(row["unclaimed_rewards"])
#         votes = getAssetAmount(row["votes"])
#         has_rewards = unclaimed_rewards > 0
#         if not has_rewards and votes > 0 and row["producers"] :
#             for prod in row["producers"] :
#                 pn = prod["key"]
#                 last_rewards_per_vote = decimal.Decimal(prod["value"]["last_rewards_per_vote"])
#                 rewards = (prods[pn] - last_rewards_per_vote) * votes // 10**18
#                 if rewards > 0 :
#                     has_rewards = True
#                     break
#         if has_rewards :
#             voter = row['owner']
#             ret = getJsonOutput(args.fucli + 'push action -j flon.reward claimrewards \'["' + voter + '"]\' -p ' + voter)
#             times.append(ret['processed']['elapsed'])
#     print('Elapsed time for voter claimRewards:', times)

# def updateAuth(account, permission, parent, controller):
#     run(args.fucli + 'push action flon updateauth' + jsonArg({
#         'account': account,
#         'permission': permission,
#         'parent': parent,
#         'auth': {
#             'threshold': 1, 'keys': [], 'waits': [],
#             'accounts': [{
#                 'weight': 1,
#                 'permission': {'actor': controller, 'permission': 'active'}
#             }]
#         }
#     }) + '-p ' + account + '@' + permission)

def regAccount(acct, flonQuant):

    if args.check_account_existed and runStatus(args.fucli + 'get account flon ' + acct['name']):
        return
    retry(args.fucli + 'system newaccount --transfer flon %s %s --fund-account "%s" FLON ' %
        (acct['name'], acct['pub'], flonQuant))

def stepKillAll():
    run('killall fuwal || true')
    sleep(1.5)
def stepStartWallet():
    startWallet()
    importKeys()

def stepInstallSystemContracts():
    retry(args.fucli + 'set contract flon.token ' + args.contracts_dir + '/flon.token/')
    retry(args.fucli + 'set contract flon.msig ' + args.contracts_dir + '/flon.msig/')
    retry(args.fucli + 'set contract flon.reward ' + args.contracts_dir + '/flon.reward/')
    retry(args.fucli + 'set account permission flon.reward active --add-code')

def stepCreateTokens():
    run(args.fucli + 'push action flon.token create \'["flon", "10000000000.00000000 %s"]\' -p flon.token' % (args.symbol))
    # run(args.fucli + 'push action flon.token issue \'["flon", "%s", "memo"]\' -p flon' % intToCurrency(totalAllocation))
    # allocate 90% of totalSupply
    run(args.fucli + 'push action flon.token issue \'["flon", "9000000000.00000000 %s", "memo"]\' -p flon' % (args.symbol))
    sleep(1)
def stepSetSystemContract():
    # All of the protocol upgrade features introduced in v1.8 first require a special protocol
    # feature (codename PREACTIVATE_FEATURE) to be activated and for an updated version of the system
    # contract that makes use of the functionality introduced by that feature to be deployed.

    # activate PREACTIVATE_FEATURE before installing flon.boot
    # retry('curl -X POST %s' % args.url +
    #     '/v1/producer/schedule_protocol_feature_activations ' +
    #     '-d \'{"protocol_features_to_activate": ["0ec7e080177b2c02b278d5088611686b49d739925a92d9bfcacd7fc6b74053bd"]}\'')
    # sleep(3)


    # install flon.system latest version
    retry(args.fucli + 'set contract flon ' + args.contracts_dir + '/flon.system/')
    sleep(3)

    # run(args.fucli + 'push action flon setpriv' + jsonArg(['flon.msig', 1]) + '-p flon@active')
    # sleep(1)

def stepInitSystemContract():
    run(args.fucli + 'push action flon init' + jsonArg([0, str(args.precision) + ',' + args.symbol]) + '-p flon@active')
    sleep(1)


def stepInitEvmContract():
    retry(args.fucli + 'set contract flon.evm ' + args.contracts_dir + '/evm_runtime -p flon.evm@active')
    retry(args.fucli + 'set account permission flon.evm active  --add-code -p flon.evm@active')
    params = {
        "chainid":15555,
        "fee_params": {
            "gas_price": 150000000000,
            "miner_cut":10000,
            "ingress_bridge_fee": fundToCurrency(0.01000000)
        },
        "token_contract": "flon.token"
    }
    run(args.fucli + 'push action flon.evm init' + jsonArg(params) + '-p flon.evm@active')

    run(args.fucli + 'transfer flon flon.evm "%s" "flon.evm" -p flon@active' % (fundToCurrency(1.0)))
    flonAcct = aioeos.EosAccount(
        name='flon',
        private_key=args.private_key
    )
    evm_priv_key = eth_keys.keys.PrivateKey(flonAcct.key._sk.to_string())
    evm_pub_key = evm_priv_key.public_key
    # print("ETH Private Key:", evm_key.to_hex())
    # print("ETH Public Key:", evm_key.to_hex())
    # print("ETH Address:", evm_key.to_address())
    run(args.fucli + 'transfer flon flon.evm "%s" "%s" -p flon@active' % (fundToCurrency(100.0), evm_pub_key.to_address()))
    run(args.fucli + 'push action flon.evm open' + jsonArg(["evm.miner"]) + '-p evm.miner@active')
    sleep(1)

def stepRegAccounts():
    flonQuantity = '1.00000000'
    # reg producers
    for p in accounts['producers']:
        regAccount(p, flonQuantity)
        # new producer accounts
        reward_shared_ratio = 0
        if 'reward_shared_ratio' in p:
            reward_shared_ratio = p['reward_shared_ratio']
        retry(args.fucli + 'system regproducer ' + p['name'] + ' ' + p['pub'] + ' https://flonscan.io/account/' + p['name'] + ' ' + str(reward_shared_ratio))
    sleep(1)
    # reg voters
    for v in accounts['voters']:
        regAccount(v, flonQuantity)
    sleep(1)

    # regVoters(accounts['voters'], ramFunds, 10**4 * 10**4)

def allocateVotes(voters):
    addedVotes = round(args.total_vote_stakes * 10**4)
    # voters = accounts['voters']
    voterLen = len(voters)
    dist = numpy.random.pareto(1.161, voterLen).tolist() # 1.161 = 80/20 rule
    dist.sort()
    dist.reverse()
    factor = addedVotes / sum(dist)
    allocated = 0
    for i in range(0, voterLen):
        if i + 1 < voterLen and allocated <= addedVotes:
            votes = round(factor * dist[i])
        else:
            votes = max(0, addedVotes - allocated)
        allocated += votes
        voterName = voters[i]['name']
        staked = voteToStaked(votes)
        print('%s: added votes=%s, staked=%s' % (voterName, intToCurrency(votes), intToCurrency(staked)))
        retry(args.fucli + 'transfer flon %s "%s"' % (voterName, intToCurrency(staked)))
        retry(args.fucli + 'push action flon addvote ' + jsonArg([voterName, intToCurrency(votes)]) + ' -p ' + voterName + '@active')

def voteProducers(voters, producers):
    pos = 0
    prodLen = len(producers)
    # vote producers
    for v in voters:
        prods = []
        if prodLen > 30:
            if pos + 30 < prodLen:
                prods = producers[pos:30]
            else:
                prods = producers[0:pos + 30 - prodLen] + producers[pos:]
                pos += 1
                if pos == prodLen:
                    prodLen = 0
        else:
            prods = producers
        prodNames = []
        for p in prods:
            prodNames.append(p["name"])
        prodNames.sort()
        retry(args.fucli + 'push action flon voteproducer %s -p %s@active' % (jsonArg([v["name"], "", prodNames]), v["name"]))

def stepVote():
    voters = accounts['voters']
    producers = accounts['producers']
    allocateVotes(producers)
    voteProducers(voters, producers)
    sleep(1)
    listProducers()
    sleep(5)

def error(msg):
    print("init.chain.py:", msg, '\n')
    print('init.chain.py: Tell me what to do. -a does almost everything. -h shows options.')
    sys.exit(1)

# Command Line Arguments

parser = argparse.ArgumentParser()

commands = [
    ('k', 'kill',               stepKillAll,                False,    "Kill all funod and fuwal processes"),
    ('w', 'wallet',             stepStartWallet,            True,    "Start fuwal, create wallet, fill with keys"),
    ('s', 'sys',                createSystemAccounts,       True,    "Create system accounts (flon.*)"),
    ('f', 'features',           activateFeatures,           True,    "activate features"),
    ('c', 'contracts',          stepInstallSystemContracts, True,    "Install system contracts (token, msig)"),
    ('t', 'tokens',             stepCreateTokens,           True,    "Create tokens"),
    ('S', 'sys-contract',       stepSetSystemContract,      True,    "Set system contract"),
    ('I', 'init-sys-contract',  stepInitSystemContract,     True,    "Initialiaze system contract"),
    # ('E', 'init-evm-contract',  stepInitEvmContract,        True,    "Initialiaze evm contract"),
    ('r', 'reg-accounts',       stepRegAccounts,            True,    "Register accounts"),
    ('v', 'vote',               stepVote,                   True,    "Allocate votes and vote producers for voters"),
]

parser.add_argument('--public-key', metavar='', help="FULLON Public Key", default='', dest="public_key")
parser.add_argument('--private-key', metavar='', help="FULLON Private Key", default='', dest="private_key")
parser.add_argument('--fucli', metavar='', help="fucli command", default='fucli --wallet-url http://127.0.0.1:6666 ')
parser.add_argument('--fuwal', metavar='', help="Path to fuwal binary", default='fuwal')
parser.add_argument('--contracts-dir', metavar='', help="Path to latest contracts directory", default='${HOME}/flon/contracts/flon.contracts')
parser.add_argument('--url', metavar='', help="Http url for funod", default='http://127.0.0.1:8888')
parser.add_argument('--wallet-dir', metavar='', help="Path to wallet directory", default='./wallet/')
parser.add_argument('--log-path', metavar='', help="Path to log file", default='./output.log')
parser.add_argument('--account-path', metavar='', help="Path to generating file", default='./accounts.json')
parser.add_argument('--symbol', metavar='', help="The flon.system symbol", default='FLON')
parser.add_argument('--precision', metavar='', help="The flon.system symbol", type=int, default=8)
parser.add_argument('--voter-limit', metavar='', help="Max number of voters. (-1 = no limit)", type=int, default=-1)
parser.add_argument('--total-vote-stakes', metavar='', help="Total added votes for voter to vote", type=float, default=200000000.0)
parser.add_argument('--ram-funds', metavar='', help="How much funds for each account to spend on ram", type=float, default=1.0)
parser.add_argument('--cpu-funds', metavar='', help="How much funds for each account to spend on cpu", type=float, default=1.0)
parser.add_argument('--net-funds', metavar='', help="How much funds for each account to spend on net", type=float, default=1.0)
parser.add_argument('--check-account-existed', metavar='', help="Need to check account existed", type=bool, default=False)

parser.add_argument('--producer-limit', metavar='', help="Maximum number of producers. (-1 = no limit)", type=int, default=-1)
parser.add_argument('--producer-stake-funds', metavar='', help="How much funds for each producer to spend on cpu and", type=float, default=1.0)
parser.add_argument('--num-producers-vote', metavar='', help="Number of producers for which each user votes", type=int, default=20)
parser.add_argument('-a', '--all', action='store_true', help="Do everything marked with (*)")

for (flag, command, function, inAll, help) in commands:
    prefix = ''
    if inAll: prefix += '*'
    if prefix: help = '(' + prefix + ') ' + help
    if flag:
        parser.add_argument('-' + flag, '--' + command, action='store_true', help=help, dest=command)
    else:
        parser.add_argument('--' + command, action='store_true', help=help, dest=command)

args = parser.parse_args()

args.fucli += ' --url %s ' % args.url

logFile = open(args.log_path, 'a')

logFile.write('\n\n' + '*' * 80 + '\n\n\n')

if not args.public_key:
    error('Parameter "--public-key" is invalid')
if not args.private_key:
    error('Parameter "--private-key" is invalid')

with open(args.account_path) as f:
    accounts = json.load(f)
    if args.voter_limit >= 0:
        del accounts['voters'][args.voter_limit:]
    if args.producer_limit >= 0:
        del accounts['producers'][args.producer_limit:]

haveCommand = False
for (flag, command, function, inAll, help) in commands:
    if getattr(args, command) or inAll and args.all:
        if function:
            haveCommand = True
            function()
if not haveCommand:
    error("No command found.")
