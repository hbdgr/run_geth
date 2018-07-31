#!/usr/bin/env bash

# we want to kill proccess at the end
#set -o errexit
set -o nounset


# Absolute path to this script
scriptpath=$(readlink -e "$0")
# Absolute path this script is in
scriptdir=$(dirname "$scriptpath")

conf_file="${scriptdir}/run_geth.conf"

if [[ -e ${conf_file} ]]
then
	echo "Found confguration file: ${conf_file}"
	# source variables from conf file
	. "${scriptdir}/run_geth.conf"
else
	echo "Missing 'run_geth.conf' confguration file!"
	echo "Create one based on run_geth.conf.default, in the same directory as this script."
	exit 1
fi


# 0=silenct, 1=error, 2=warn, 3=info, 4=core, 5=debug, 6=debug detail
readonly VERBOSITY=4

#---------------------------------------------------------------------
set_network() {
	if [ "$*" == "" ]; then
		echo "Empty first argument, unable to set corect network."
		echo "Provide network name as first argument, available: 'ropsten', 'main'."
		exit 1
	fi
	local network_name="$1"
	if [ "$1" == 'main' ]; then
		echo 0
	elif [ "$1" == 'ropsten' ]; then
		echo 1
	else
		echo "'${network_name}' is a bad network name!"
		echo "Provide network name as first argument, available: 'ropsten', 'main'."
		exit 1
	fi
}

# setting network as first agr
readonly TEST_NETWORK=$(set_network "$*")
readonly USE_BOOTNODES=1

#---------------------------------------------------------------------
create_missing_dirs() {
	# get rid of file name
	local dir=$(echo $1 | rev | cut -d/ -f 2- | rev)
	if [[ ! -d $dir ]]
	then
		echo "Creating path: ${dir}"
		mkdir -p $dir
	fi
}
create_missing_dirs "$LOGS_PATH"
create_missing_dirs "$IPCFILE_PATH"

# do not create empty
if [[ -n "${DATA_DIR}" ]]
then
	create_missing_dirs "$DATA_DIR"
fi

#---------------------------------------------------------------------
# checking GETH_PATH - with version argument
check_geth_path() {
	printf "Checking Geth Path: "
	if [[ -n $(${GETH_PATH}/build/bin/geth version | grep Geth) ]]
	then
		echo "$(${GETH_PATH}/build/bin/geth version)"
		echo "OK"
	else
		echo "Fail to run Geth! Set correct GETH_PATH variable."
		echo "exiting ..."
		exit 1
	fi
}
check_geth_path
#---------------------------------------------------------------------

declare -a geth_options=("--syncmode ${SYNCMODE}" " --cache ${CACHE}" "--maxpeers ${MAXPEERS}")


# append verbosity level
geth_options=("${geth_options[@]}" "--verbosity ${VERBOSITY}")

if [[ ${IPC_DISABLE} == 0 ]]
then
	# default admin,debug,eth,miner,net,personal,shh,txpool,web3
	ipcAPI="admin,debug,eth,miner,net,web3,personal"
	geth_options=(${geth_options[@]}	\
		"--ipcpath ${IPCFILE_PATH}"	\
	)
else
	# append --ipcdisable option to array
	geth_options=(${geth_options[@]}	\
		"--ipcdisable"			\
	)

fi

if [[ ${RPC_ENABLE} == 1 ]]
then
	# RPC additional options
	rpcAPI="web3,db,net,eth"

	# append rpc options
	geth_options=(${geth_options[@]}		\
		"--rpc"					\
		"--rpcport=${rpcPort}"			\
		"--rpccorsdomain=${rpcCorsDomain}"	\
		"--rpcapi=${rpcAPI}"			\
		)
fi

if [[ ${TEST_NETWORK} == 1 ]]
then
	echo "Setting 'ropsten' test network.."
	networkID=3 	# Ropsten testnet
	# bootnodes=''

	if [[ ${USE_BOOTNODES} == 1  ]]
	then
		# ropsten bootnodes // actual peers from: https://gist.github.com/rfikki
		bootnodes="enode://256405c3af6b9369c84bb90927c99a1edabe061a62e3c7bec19f23e3c8ad6fea9cc5c47e174435bbb415852e344ad9d7bb61c158e69fb5f29f16cc787f85cf2c@92.111.252.195:63451,enode://27f7328ef96a15f6f47ddeba8ba2a50952e430a3f294bd0e479e47239123167ba67fb46057405b1baa1716ee8ef5cd58b982b241e82d1fd8f5891d77f1a84a51@85.223.209.56:51938,enode://42de7d88a5473d6317f1826ca87689b2b9566a2ece72da0c78d529b61295264b2aec8c13fc3e2d1f5d05fbfb0c2ab98af2c64a6f6fa9dc7236b28d97323d2ba4@136.62.220.147:30303,enode://6991bbef05ca85e9cb0cfab1b8f9427500bb004ff21edb189760d146bf5f37015202b565e0af752f2975f3f8bdc672ab8b39d378b0911874883ac70cdf23c83d@121.122.127.186:45534,enode://9e99e183b5c71d51deb16e6b42ac9c26c75cfc95fff9dfae828b871b348354cbecf196dff4dd43567b26c8241b2b979cb4ea9f8dae2d9aacf86649dafe19a39a@51.15.79.176:41462,enode://9eccca5941e191de1f43345c7bbcb8a0a77fe383329d5f85da72d445f72bb9561768118443604b474022ce7e9dc58779acc8486fb882801e61a800ca0c089930@140.112.238.158:37162,enode://f55d3f3a5e21bb4e0bcd046ccc880f4e79bddee570a9909c72de61470b48e0309d38460b28408c50d689cf4629a3bb0877f7556d142950cb3d3b3251ced405a1@52.212.59.171:30303"
	fi

	# append testnet options
	geth_options=(${geth_options[@]}		\
		"--testnet" 				\
		"--networkid=$networkID" 		\
		"--bootnodes=$bootnodes"		\
		)
else
	echo "Setting 'main' ethereum network.."
	if [[ ${USE_BOOTNODES} == 1  ]]
	then
		# frontier bootnodes
		bootnodes="enode://1454de9e78e3669c551cf8e00bb6c32a12398565f90708fd66e8ced16be714a79cbad1c36b2126b19fb1d179c0e6f4f52e76ba7a44c2c7f4944ad7a931135f1e@52.76.82.200:58784,enode://1f90d0193f6bd2a97384ebbaa2371a409e043c69a0a40779468866d30f042c0cd997fabfd14d90a42e36c4b807d48dc0f6fbeb321b5a6abe482e9b4746d356c4@47.52.246.145:44238,enode://248aa5c13f8f5affb978abe03467c31b3b6292a93b4ebce878c5939c1f5151ea33adc7dd0b9852685e1aca59da345bf32a90cf694dbfc56bac9f0e2beb68c163@195.201.59.40:41650,enode://2d433fcb4f5720abc3fa026fac37ee830099b5eeb94674d13403f98c41dac802f4e749fd57344daee1c8e89f4ff85172cfc8fc458dd181a8aef355becf25332f@18.196.102.254:37772,enode://33346f7f5a75f0354f7fdc85f99783626767ca2b632b08bd73611f25f4d136052d8ea163ce4a00e576c4dd4cb1d248e6d5fea2bdaad4a5096fe627a70a4e4929@209.95.50.38:30303,enode://353acd557f21dbd5a02b873bd9161c128459188fc0e253342adec8645e7adef0f1ca52db80c22f5a9581f950d6183e9e9c836c5375091089fab11918dc799c5d@54.147.107.38:30303,enode://432b36f37fde4f50a5ec1678ea333bf7db924546d3b11862e715b94f6075a08eba5eb3408bc7912abbd26a17d88e0adc02f51832388575972f73d2ec8c861c9a@88.198.54.76:30303,enode://4634e75fc55fb13477c1934ce22221f0dff209156d36b02e07d516b82ce6ab4aaa31762af67aa74f497cc069ee2a39dfa965516e4129886b404f3a78f4bd2de2@23.108.208.52:30303,enode://53d79e4d7cf1dc40665ffb7294fb3c0d16a294caff3447141242f0796bd64afcee67aa69cba69b6ceb9d001fc3696998590c98594b60479118a7bd74b96ee201@47.91.242.118:30303,enode://5d08d109318149daca3c6f27bf24a28074172fb1395717593ab5266753bce6113a01f5aa9dad7741c6b1efacc245057272e7f1b3dc4c20aaf69dbe3116d05ead@54.37.85.202:30303,enode://6e865c2bfc081d25ce424e2c509f11601b25b48d646ae74ab5c3dd3e0abf3d91d5671ca7e6e381c679b35909831d1f582cf84636d17c0bb623ec8367dec331ba@185.138.8.35:45950,enode://6f41427b3572c3b5478c55c14c015c6a60be3b3878450bc185e06c498e9d824627cf5266689a786ae1609ccfc013a7d0c73d37bc17becb7fefa286c784d108b7@5.39.36.69:60546,enode://75fabe7e18934ed9d0355544ad2042061a29c2673342704cca05f166112d52505957e8687a96af2f09d6f3b0b932d2010ea9fd18092f5477bf364f84d6e1f777@104.46.49.136:30303,enode://7f2a5eeaac72c1f897630af560602923ef161566e9177eaf4f1115005c2e28ea51da6f218bee1ee364759d9634188305127237636794aa7f13c23886266f5f63@184.18.48.15:49309,enode://81b2a7d1a10cf9618fdbd1cca7644a39e2550350ea1f6a941cd8bdf0acd77da8147dd800e98eee55044588e6ccdd679822d77f70adfabf89359807167b2bf83b@67.181.16.46:55534,enode://883c188d2b24f182a48276b50a263b42892b7f7c896c0fc3a2ef02d529848c215c284b41f2470a855573cbe629e3165eddfe02845c8569ebaf740f466c678917@18.191.2.135:60726,enode://8b101c2b907d606a52de162f7179793e1394b78484c14d0ebb231a621e5ece3a517734bff589217e62e975dc5b08835443961a93336c43f91a6a870ed9093c1f@121.196.208.250:55354,enode://8f9d6de0d6974c81a35bad8dabb40cf4d33722800e99b897ddbf2eed0f5bff34edb7828a15b1419ea02463bb68f47b79fe455ae5d3284586b7018413707c44e2@141.0.148.234:50992,enode://9de1cabecb6526cd3d86e51bf2353bdf43c5c5abbe92c9950d2589f8412f4db3ef2b57b95d830a41283d82484a4c35a264f71e1fa3f3262a089e5b95c40b1395@165.227.50.4:55350"

	# append bootnodes, leave default (1) Frontier networkId
	geth_options=(${geth_options[@]}		\
		"--bootnodes=$bootnodes"		\
		)

	fi
fi


if [[ ${NODISCOVER} == 1 ]]
then
	geth_options=(${geth_options[@]} "--nodiscover")
fi


if [[ ${MINING_MODE} == 1 ]]
then
	miner_threads=3
	rwd_address="0x4283bc4327eae94f58a08689648f1d7c578156a0"  # Public address for block mining rewards

	# append testnet options
	geth_options=(${geth_options[@]}		\
		"--mine" 				\
		"--minerthreads=${MINING_THREADS}" 	\
		"--etherbase=${rwd_address}"		\
		)
fi

#---------------------------------------------------------------------

echo "Geth command: ${GETH_PATH}/build/bin/geth  ${geth_options[@]}"
set -x
"${GETH_PATH}/build/bin/geth" "${geth_options[@]}" 2>>${LOGS_PATH} &
GETH_PROC_ID=$!
echo "process id: $GETH_PROC_ID"

set +x

# setting permission for ipc file
if [[ ${IPC_DISABLE} == 0 ]]
then
	# wait for geth.ipc to be created
	sleep 120

	# add file to ipc-eth group
	chown :ipc-eth "${IPCFILE_PATH}"

	# add ipc-eth group write permission
	chmod g+w "${IPCFILE_PATH}"
fi


# Re-attach geth console
if [[ ${CONSOLE_MODE} == 1 ]]
then
	if [[ ${IPC_DISABLE} == 0 ]]
	then
		"${GETH_PATH}/build/bin/geth" "attach" "ipc://${IPCFILE_PATH}"
	else
		"${GETH_PATH}/build/bin/geth" "attach" "http://localhost:${rpcPort}"
	fi
fi

# exiting and killing running process
while :
do
	echo ""
	read -n1 -r -p "Press 'q' to kill geth and exit..." key

	if [ "$key" = 'q' ]; then
		# kill geth instance
		kill -9 "$GETH_PROC_ID" >/dev/null 2>&1;
		printf "\nBackground geth processes have exited.\n"
		break
	fi
done
