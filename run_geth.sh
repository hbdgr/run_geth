#!/usr/bin/env bash

set -o nounset

# Absolute path to this script
scriptpath=$(readlink -e "$0")
# Absolute path this script is in
scriptdir=$(dirname "$scriptpath")


check_configuration() {
	local conf_file="${scriptdir}/run_geth.conf"

	if [[ -e ${conf_file} ]]; then
		echo "Found confguration file: ${conf_file}"
		# source variables from conf file
		. "${scriptdir}/run_geth.conf"
	else
		echo "Missing 'run_geth.conf' confguration file!"
		echo "Create it first, based on run_geth.conf.default, in the '${scriptdir}' directory."
		exit 1
	fi
}

#---------------------------------------------------------------------
check_configuration
declare -a geth_options=("--syncmode ${SYNCMODE}" " --cache ${CACHE}" "--maxpeers ${MAXPEERS}")
#---------------------------------------------------------------------

get_network() {
	local network_name="$1"
	if [ "$1" == "" ]; then
		echo "empty"
	fi
	if [ "$1" == 'main' ]; then
		echo 0
	elif [ "$1" == 'ropsten' ]; then
		echo 3
	else
		echo "${network_name}"
	fi
}

set_network() {
	# setting network from first agr
	readonly ETH_NETWORK=$(get_network "$*")
	if [[ ${ETH_NETWORK} == 3 ]]; then
		echo "Setting 'ropsten' test network.."
		networkID=3   # Ropsten testnet

		if [[ ${USE_BOOTNODES} == 1  ]]; then
			bootnodes="${BOOTNODES_ROPSTEN}"
		fi

		# append testnet options
		geth_options=(${geth_options[@]} \
			"--testnet" \
			"--networkid=$networkID" \
			"--bootnodes=$bootnodes" \
			)
	elif [[ ${ETH_NETWORK} == 0 ]]; then
		echo "Setting 'main' ethereum network.."
		if [[ ${USE_BOOTNODES} == 1  ]]; then
			bootnodes="${BOOTNODES_ROPSTEN}"
		fi

		# append bootnodes to mainnet networkId
		geth_options=(${geth_options[@]} \
			"--bootnodes=$bootnodes" \
			)
	else
		if [[ "${ETH_NETWORK}" == "empty" ]]; then
			echo "Empty first argument, unable to set correct network."
			echo "Provide network name as first argument, available: 'ropsten', 'main'."
		else
			echo "'${ETH_NETWORK}' is a bad network name!"
			echo "Provide network name as first argument, available: 'ropsten', 'main'."
		fi
		exit 1
	fi
}

create_missing_dirs() {
	# get rid of file name
	local dir=$(echo $1 | rev | cut -d/ -f 2- | rev)
	if [[ ! -d $dir ]]; then
		echo "Creating path: ${dir}"
		mkdir -p $dir
	fi
}

#---------------------------------------------------------------------
create_missing_dirs "$LOGS_PATH"
create_missing_dirs "$IPCFILE_PATH"

# do not create empty
if [[ -n "${DATA_DIR}" ]]; then
	create_missing_dirs "$DATA_DIR"
fi
#---------------------------------------------------------------------

# checking GETH_PATH
check_geth_path() {
	printf "Checking Geth Path: "
	if [[ -n $(${GETH_PATH} version | grep Geth) ]]; then
		echo "$(${GETH_PATH} version)"
	else
		echo "Fail to run Geth! Set correct GETH_PATH variable."
		echo "exiting ..."
		exit 1
	fi
}

set_verbosity() {
	# append verbosity level
	geth_options=("${geth_options[@]}" "--verbosity ${VERBOSITY}")
}

configure_ipc() {
	if [[ ${IPC_DISABLE} == 0 ]]; then
		# default admin,debug,eth,miner,net,personal,shh,txpool,web3
		ipcAPI="admin,debug,eth,miner,net,web3,personal"
		geth_options=(${geth_options[@]} \
			"--ipcpath ${IPCFILE_PATH}" \
		)
	else
		# append --ipcdisable option to array
		geth_options=(${geth_options[@]} \
			"--ipcdisable" \
		)
	fi
}

configure_rpc() {
	if [[ ${RPC_ENABLE} == 1 ]]; then
		# RPC additional options
		rpcAPI="web3,db,net,eth"

		# append rpc options
		geth_options=(${geth_options[@]} \
			"--rpc" \
			"--rpcport=${RPC_PORT}" \
			"--rpccorsdomain=${RPC_CORS_DOMAIN}" \
			"--rpcapi=${rpcAPI}" \
			)
	fi
}

configure_nodiscover() {
	if [[ ${NODISCOVER} == 1 ]]; then
		geth_options=(${geth_options[@]} "--nodiscover")
	fi
}

configure_mining() {
	if [[ ${MINING_MODE} == 1 ]]; then
		# append testnet options
		geth_options=(${geth_options[@]} \
			"--mine" \
			"--minerthreads=${MINING_THREADS}" \
			"--targetgaslimit=${TARGET_GASLIMIT}" \
			"--etherbase=${REWARD_ADDRESS}" \
			)
	fi
}

cleanup_geth() {
	# Kill the geth instance that we started (if we started one and if it's still running).
	if [ -n "$GETH_PROC_ID" ] && ps -p $GETH_PROC_ID > /dev/null
	then
		kill $GETH_PROC_ID
		printf "\nBackground geth processes have exited.\n"
	fi
}

# force run, return new PID
start_geth() {
	# kill existing geth instance if it is already running
	local LAST_GETH_PID=`pgrep geth`
	if [[ -n ${LAST_GETH_PID} ]]; then
		kill $LAST_GETH_PID; wait
	fi

	# run
	"${GETH_PATH}" "${geth_options[@]}" 2>>${LOGS_PATH} &
	# assign pid to variable
	GETH_PROC_ID="${!}"
}

wait_for_ipc_file() {
	echo 'waiting for IPC endpoint...'
	while :
	do
		if [[ -n $(tail -n 20 "$LOGS_PATH" | grep "IPC endpoint opened") ]]; then
			printf "geth.ipc file is ready.\n"
			break;
		fi
	done
}

set_permissions() {
	# setting permission for ipc file
	if [[ ${IPC_DISABLE} == 0 ]]; then
		# wait for geth.ipc to be created
		wait_for_ipc_file

		# add file to ipc-eth group
		chown :ipc-eth "${IPCFILE_PATH}"

		# add ipc-eth group write permission
		chmod g+w "${IPCFILE_PATH}"
	fi

	# add log file to ipc-eth group
	chown :ipc-eth "${LOGS_PATH}"
}

attach_console() {
	# Re-attach geth console
	if [[ ${CONSOLE_MODE} == 1 ]]; then
		if [[ ${IPC_DISABLE} == 0 ]]; then
			"${GETH_PATH}" "attach" "ipc://${IPCFILE_PATH}"
		else
			"${GETH_PATH}" "attach" "http://localhost:${RPC_PORT}"
		fi
	fi
}

#---------------------------------------------------------------------
set_network "${*}"
check_geth_path
set_verbosity
configure_ipc
configure_rpc
configure_nodiscover
configure_mining

echo "Geth command: ${GETH_PATH}/build/bin/geth  ${geth_options[@]}"
start_geth
echo "Geth process id: $GETH_PROC_ID"

# Executes cleanup function at script exit.
trap cleanup_geth EXIT

set_permissions
attach_console
