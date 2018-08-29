# run geth

A small script that makes starting geth easier.

## configure
Instead of adding an endless line of options directly to the geth during each run,
script requires ```run_geth.conf``` configuration file, that can be easily managed.


**example (```run_geth.conf.default```):**
```
GETH_PATH="/home/user/eth/geth/build/bin/geth"
LOGS_PATH="/home/user/eth/logs/geth.log"


# leave empty "" for default location '${HOME}/.ethereum'
DATA_DIR=""

# 0=silenct, 1=error, 2=warn, 3=info, 4=core, 5=debug, 6=debug detail
VERBOSITY=4


# 'fast', 'light' or 'full'
SYNCMODE='fast'
CACHE=1024
MAXPEERS=64


# RPC options
RPC_ENABLE=0
RPC_PORT="8545"
RPC_CORS_DOMAIN="localhost"

# Interprocess communication is enabled as default
IPC_DISABLE=0
IPCFILE_PATH="/home/user/eth/ipc/geth.ipc"


# Set 1, if you do not want geth to find new peers
NODISCOVER=0

# attach console
CONSOLE_MODE=1

# CPU mining
MINING_MODE=0
MINING_THREADS=4


USE_BOOTNODES=0

# ropsten bootnodes
BOOTNODES_ROPSTEN=""

# frontier bootnodes
BOOTNODES_MAIN=""
```

## run
Mainnet:
```
$ ./run_geth main
```
Ropsten testnet:
```
$ ./run_geth ropsten
```
