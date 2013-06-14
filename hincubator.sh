#!/usr/bin/env bash

function check_files() {
	while [ $# -gt 0 ];do
		[ ! -e ${1} ] && echo "Missing ${1} "
		shift
	done
	return
}

function error() {
	echo "[__ERROR__] ""$@"
	exit -1
}

#input /foo/bar
#output \/foo\/bar
function unescape_bs() {
	echo "$@" | sed "s#/#\\\\/#g"
}

TIMESTAMP="$(date +%Y%m%d%H%M%S)"

basedir=`dirname "$0"`
basedir=`cd "$basedir"; pwd`

function usage() {
cat << endl
Usage: $(basename "$0") 
	[-c CONFIG_DIR]
	[-o OUTPUT_DIR]
	[-boot BOOT_SERVER]
	[-install INSTALL_SERVER]
	[-overwrite]
	[-h]
endl
}
while [ $# -gt 0 ]; do
	case "$1" in
		-h)
			usage; exit 0;;
		-c)
			shift;SRC_CONFIG=$1;;
		-o)
			shift;OUTPUT=$1;;
		-boot)
			shift;BOOT_SERVER=$1;;
		-install)
			shift;INSTALL_SERVER=$1;;
		-overwrite)
			OVERWRITE=yes;;
		*)
			echo "Uknown option $1"
			usage; exit -1;;
	esac
	shift
done

SRC_CONFIG=${SRC_CONFIG:-$basedir/config}
OUTPUT=${OUTPUT:-$basedir/output}

[ "${BOOT_SERVER}" = "" ] && BOOT_SERVER=`resolveip ${HOSTNAME} | egrep -o "[0-9]+\.[0-9]+.[0-9]+.[0-9]+"`
[ "${INSTALL_SERVER}" = "" ] && INSTALL_SERVER=`resolveip ${HOSTNAME} | egrep -o "[0-9]+\.[0-9]+.[0-9]+.[0-9]+"`

[ "${BOOT_SERVER}" = "" -o "${INSTALL_SERVER}" = "" ] && error "Can't figure out server IP address"

HOSTFILE=${SRC_CONFIG}/ALLHOSTS
MACFILE=${SRC_CONFIG}/ALLMACS
IPFILE=${SRC_CONFIG}/ALLIPS

MAC_TEMPLATE=${SRC_CONFIG}/MAC.template
IP_TEMPLATE=${SRC_CONFIG}/IP.template

[ ! -d ${SRC_CONFIG} ] && error "Source directory ${SRC_CONFIG} doesn't exists"
[ -e ${OUTPUT} -a "${OVERWRITE}" != "yes" ] && error "Output directory ${OUTPUT} exists!"

ALL_HOSTS=($(cat ${HOSTFILE}))
ALL_MACS=($(cat ${MACFILE}))
ALL_IPS=($(cat ${IPFILE}))

LEN=${#ALL_HOSTS[@]}

[ ${#ALL_HOSTS[@]} -ne ${#ALL_MACS[@]} -o ${#ALL_MACS[@]} -ne ${#ALL_IPS[@]} ] && \
	error "Mismatched HOST and IP definition (${HOSTFILE}, ${MACFILE}, ${IPFILE})"

DHCP_CONF=${OUTPUT}/dhcpd.conf
TFTP_ROOT=${OUTPUT}/tftp
INSTALL_ROOT=${OUTPUT}/install

m=$(check_files ${SRC_CONFIG} ${HOSTFILE} ${MACFILE} ${IPFILE} ${MAC_TEMPLATE} ${IP_TEMPLATE})
[ "${m}" != "" ] && error "${m}"

mkdir -p ${TFTP_ROOT}
mkdir -p ${INSTALL_ROOT}

if [ "`ls ${SRC_CONFIG}/BOOT_SERVER`" != "" ]; then
	result=`cp -rl ${SRC_CONFIG}/BOOT_SERVER/* ${TFTP_ROOT}/ 2>&1`
else
	echo "[__NOTE__] No file was brought to boot server at ${TFTP_ROOT}. You may manually do this."
fi

[ "${result}" != "" ] && error "${result}"

if [ "`ls ${SRC_CONFIG}/INSTALL_SERVER`" != "" ]; then
	result=`cp -rl ${SRC_CONFIG}/INSTALL_SERVER/* ${INSTALL_ROOT}/ 2>&1`
else
	echo "[__NOTE__] No file was brought to install server at ${INSTALL_ROOT}. You may manually do this."
fi

[ "${result}" != "" ] && error "${result}"

truncate -s 0 ${DHCP_CONF}

read -r -d '' var <<EOF
#
# Define subnet, if MAY required.
# Examples:
#
#    subnet 192.168.1.0 netmask 255.255.255.0 {
#        range 192.168.1.2 192.168.1.254;
#        deny unknown-clients;
#    }
#
# Add the following lines to DHCP conf ('/etc/dhcp/dhcpd.conf' for Centos 6)
#--------------------------------------------------------------------------------
group pxe_${TIMESTAMP} {
    filename "pxelinux.0";
EOF
echo "${var}" >> ${DHCP_CONF}

for i in `seq 0 $(($LEN-1))`;do
IPADDR="${ALL_IPS[${i}]}"
MACADDR=`echo ${ALL_MACS[${i}]} | tr '-' '='`
read -d '' var <<ENDL
       host ${IPADDR} \{
           hardware ethernet ${MACADDR};
           fixed-address ${IPADDR};
           next-server ${BOOT_SERVER};
       \}
ENDL
echo "${var}" >> ${DHCP_CONF}
done
echo "}"  >> ${DHCP_CONF}

TMPFILE=/tmp/hIncublator.tmp
PXECFG_DIR=${TFTP_ROOT}/pxelinux.cfg
mkdir -p ${PXECFG_DIR}
for i in `seq 0 $(($LEN-1))`;do
	IPADDR=${ALL_IPS[${i}]}
	MACADDR=${ALL_MACS[${i}]}
	sed "s/@INSTALL_SERVER@/${INSTALL_SERVER}/" ${MAC_TEMPLATE} | sed "s/@IPADDR@/${IPADDR}/" | sed "s/@INSTALL_ROOT@/$(unescape_bs ${INSTALL_ROOT})/" > ${TMPFILE}
	mv ${TMPFILE} ${PXECFG_DIR}/01-$(echo ${MACADDR} | tr ":" "-")
done

KS_DIR=${INSTALL_ROOT}/ks
mkdir -p ${KS_DIR}
for i in `seq 0 $(($LEN-1))`;do
	IPADDR=${ALL_IPS[${i}]}
	HOST=${ALL_HOSTS[${i}]}
	sed "s/@INSTALL_SERVER@/${INSTALL_SERVER}/" ${IP_TEMPLATE} | sed "s/@IPADDR@/${IPADDR}/" | sed "s/@INSTALL_ROOT@/$(unescape_bs ${INSTALL_ROOT})/" | sed "s/@HOST@/${HOST}/"> ${TMPFILE}
	mv ${TMPFILE} ${KS_DIR}/ks-${IPADDR}.cfg
done

read -r -d '' var <<EOF
1) Enable tftp and point tftp home to "${TFTP_ROOT}".
     Check /etc/xinetd.d/tftp
2) Export "${INSTALL_ROOT}" in "/etc/exports" for NFS. E.g.,
     ${INSTALL_ROOT}        *(ro,sync,no_root_squash)
3) Add $DHCP_CONF to DHCP conf.
     Check /etc/dhcp/dhcpd.conf' for Centos6
4) (Re-)enable services:
     service dhcpd restart
     service nfs restart
     service xinetd restart
EOF

echo "${var}" > ${OUTPUT}/README

echo "OK. It's almost done! Next, you may"
echo "${var}"
