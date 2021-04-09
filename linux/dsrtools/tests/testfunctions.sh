#
# testfunctions.sh contains useful functions for executing dsrtools tests.
# It is sourced by each of the individual tests.
# The functions are written as ksh functions.
#

#
# Basic settings for ksh.
#
set -o nounset
set -o errexit

function init
{
	#
	# Set up some global variables.
	#
	ErrIgnore=0
	KeepTmpFiles=0
	Replace=0
	NoRun=0
	Verbose=0
	Trun=./trun
	Tinfo=./tinfo
	set -A TmpFiles
	set -A TrunArgs
	ModprobeConfFile="/etc/modprobe.d/~~~dsrtest.conf"
	ip6_disabled && Ip6Disabled=1 || Ip6Disabled=0

	# Define the collating sequence we're using for testing.
	export LC_ALL=C

	while getopts ikrt:v OPTION; do
		case $OPTION in
		  i)	ErrIgnore=1
			TrunArgs+=( -i )
		        ;;
		  k)	KeepTmpFiles=1
			TrunArgs+=( -k )
			;;
		  r)	Replace=1
			TrunArgs+=( -r )
			;;
		  v)	Verbose=1
			TrunArgs+=( -v )
			;;
		  t)	Table=$OPTARG
			TrunArgs+=( -t ${Table} )
			;;
		esac
	done

        [[ -x $DSRCTL ]] || { print -- "DSRCTL ($DSRCTL) isn't executable or doesn't exist."; exit 1; }

	[[ ${Tname+_} ]] && [[ -n $Tname ]] || Tname=${PWD##*/}

	. "$Tinfo" || { print -- "Failed to source \"$Tinfo\"."; exit 1; }

	[[ ${Table+_} ]] || { print -- "Iptables Table not provided for $Tname"; exit 1; }

	trap CleanUp HUP INT QUIT TERM

	# Clear up anything that is running.
	dsrcleanup

	# Dup stdout to FD 3.
	# This lets us do
	#     run foo > /dev/null 2>&1
	# The prints in run come out to stdout and the output from foo goes to /dev/null
	exec 3>&1

	Node=$(uname -n)
	IpAddr=$(getent ahostsv4 "$Node" | grep STREAM | awk '{print $1}')

	return 0
}

# Print the cmd ($@) according to Verbose.
#     Verbose==0: don't print the cmd
#     Verbose==1: print the cmd
#     Verbose>=2: print the curdate and cmd
# The first arg is always the verbose limit.
# If $Verbose < $vlevel, then the remaining arguments are not printed.
function vprt
{
	typeset vlevel
	typeset curdate=

	vlevel=$1
	shift

	(( Verbose >= vlevel )) || return 0
	(( Verbose < 2 )) || curdate="$(date +%Y%m%d-%H:%M:%S): "
	print -u3 -- "$curdate$@"
}

# For convenience.
function vprt1 { vprt 1 "$@"; }
function vprt2 { vprt 2 "$@"; }
function vprt3 { vprt 3 "$@"; }
function vprt4 { vprt 4 "$@"; }
function vprt5 { vprt 5 "$@"; }

function vrun
{
	typeset vlevel=$1
	typeset rv=0

	shift

	vprt $vlevel "+$@"
	"$@" || rv=$?
	(( rv == 0 )) || vprt $vlevel "FAILED (rv=$rv): $@"

	return $rv
}

# For convenience.
function vrun1 { vrun 1 "$@"; }
function vrun2 { vrun 2 "$@"; }
function vrun3 { vrun 3 "$@"; }
function vrun4 { vrun 4 "$@"; }
function vrun5 { vrun 5 "$@"; }

function run
{
	# Default the verbose level to 1 for printing commands.
	vrun1 "$@"
}

# Check if IPv6 has been disabled.
#
# Return 0 if IPv6 is disabled or an error was detected.
# Return 1 if IPv6 is enabled.
#
# Note that RHEL7 behaves differently from RHEL8 when calling ip6tables if
# IPv6 is disabled on the kernel command line (ipv6.disable=1).
#     On RHEL8, ip6tables returns information even if IPv6 is disabled.
#     On RHEL7, ip6tables just fails with the following error message.
#         ip6tables v1.4.21: can't initialize ip6tables table `filter': \
#                            Address family not supported by protocol
#         Perhaps ip6tables or your kernel needs to be upgraded.
#     This difference causes dsrctl to not even try to call ip6tables if IPv6
#     is disabled, not even to get status.
function ip6_disabled
{
	typeset sysmodfile=/sys/module/ipv6/parameters/disable
	typeset procfile=/proc/sys/net/ipv6/conf/all/disable_ipv6

	# Both files must exist or IPv6 is disabled.
	[[ -e $sysmodfile ]] && [[ -e $procfile ]] || return 0

	# If both file values are 0, IPv6 is enabled.
	(( $(<$sysmodfile) )) || (( $(<$procfile) )) || return 1

	return 0
}

function RunTest
{
	typeset rv=0

	init "$@"

	# If IPv6 is disabled and the test is an IPv6 test, then skip it.
	if ip6_disabled && [[ $Tname == @(ip46+(?)|ip6+(?)) ]]; then
		print -- "===== NOIPV6: $(date +'%Y-%m-%d %T'): $Tname $TDESC"
		return 0
	fi

	#
	# Check for an executable called $Trun in the directory and run it.  If
	# $Trun exists, then it's the test.  If it doesn't exist, then we run the
	# default test.
	#
	# If $Trun exists, then it must return 0 for success and nonzero for failure.
	#
	if [[ ! -x $Trun ]]; then
		unload_kmod
		load_kmod

		RunDefaultTest || rv=$?

		unload_kmod
	else
		"$Trun" "${TrunArgs[@]}"
		(( $? == 0 )) || { print -- "Actual rv=$? Expected rv=0"; rv=1; }
	fi

	(( rv == 0 )) && \
		print -- "===== PASSED: $(date +'%Y-%m-%d %T'): $Tname $TDESC" || \
		print -- "===== FAILED: $(date +'%Y-%m-%d %T'): $Tname $TDESC"

	return $rv
}

function cleanup
{
	typeset retval=$?

	print -- "Cleaning up..."

	#"${DSRCTL}" -f /dev/null -a stop > /dev/null 2>&1

	exit $retval
}

function dsrcleanup
{
	# Clean out the PATH in case a test was changing it.
	PATH= "${DSRCTL}" -f /dev/null -a stop > /dev/null 2>&1 || :
	(( KeepTmpFiles )) || rm -f -- "${TmpFiles[@]}"
}

# Returns
#     1 if the xt_DADDR module supports requesting any iptables table
#     0 if the xt_DADDR module does not support requesting any iptables table
function anytable_supported
{
	typeset modinfoout

	modinfoout=$(modinfo --field parm xt_DADDR 2>/dev/null)
	[[ -n $modinfoout ]] && return 0 || return 1
}

function load_kmod
{
	typeset -a cmd

	#
	# We need to use options in the conf file because of the dsrctl
	# restart command, which we use and test.  Since we can't get in
	# between the stop and the start in the dsrctl restart, we need to use
	# a conf file.
	#
        # Note that we choose a name that is at the end of the collating
        # sequence we're using (LC_ALL=C) so that it's the last file that is
        # read so that it overrides anything else that is installed that might
        # conflict.  Or so we hope.
	#
	if anytable_supported; then
		TmpFiles+=( "$ModprobeConfFile" )
		cmd=( echo "options xt_DADDR table=$Table" )
		run "${cmd[@]}" > $ModprobeConfFile
	fi

	cmd=( modprobe xt_DADDR )
	run "${cmd[@]}"
}

function unload_kmod
{
	typeset -a cmd

	cmd=( modprobe -r xt_DADDR )
	run "${cmd[@]}" || :
}

function RunDefaultTest
{
	typeset rv=0

	# Clear up anything that is running.
	dsrcleanup

	(( rv && ! ErrIgnore )) || docmd start  ""   n:20  1 || rv=1
	(( rv && ! ErrIgnore )) || docmd status ""   n:20  1 || rv=1
	(( rv && ! ErrIgnore )) || docmd stop   ""   n:20  1 || rv=1

	# Clear up anything that is running.
	dsrcleanup

	return $rv
}

function removedates
{
	typeset output=$1

	typeset -a lines
	typeset dateprefixpat line oifs

	dateprefixpat="{8}([\d])-{2}([\d]):{2}([\d]):{2}([\d]): "

	oifs=$IFS
	IFS=$'\n'
	lines=( $(print -- "$output") )
	IFS=$oifs

	for line in "${lines[@]}"; do
		print -- "${line#{8}([\d])-{2}([\d]):{2}([\d]):{2}([\d]): }"
	done
}


# The return value indicates whether the test succeeded or failed, not
# the individual command.  If the dsrctl command is supposed to fail with
# an exitval of 1 and that's indicated in the tinfo file, then the test
# succeeds.
function docmd
{
	typeset action=$1
	typeset args=$2
	typeset confloc=$3
	typeset expectednum=$4

	typeset -a cmd
        typeset cmdrv conftype confval diffrv expectedfile expectedrvname ignoredates
        typeset rv=0

	# The confloc is the location of the config file.
	# It can be a confnum, file, or directory.
	# Examples:
	#     f:-              # config file is /dev/null
	#     f:filename       # config file is filename
	#     n:20             # config file is 20-vip.conf
	#     d:.              # config dir is .
	#     d:/etc/dsr.d     # config dir is /etc/dsr.d
	conftype=${confloc%%:*}
	confval=${confloc##$conftype:}

	if [[ $conftype == f ]]; then
		if [[ $confval == - ]]; then
			cmd=( "$DSRCTL" -f /dev/null $args "$action" )
		else
			cmd=( "$DSRCTL" -f "$confval" $args "$action" )
		fi
	elif [[ $conftype == d ]]; then
		cmd=( "$DSRCTL" -d "$confval" $args "$action" )
	elif [[ $conftype == n ]]; then
		cmd=( "$DSRCTL" -f "$confval-vip.conf" $args "$action" )
	fi

	expectedfile="expected.${action}.${expectednum}"
	if [[ -f "$expectedfile.$Table" ]]; then
		cp "$expectedfile.$Table" "$expectedfile"
		TmpFiles+=( "$expectedfile" )
	fi

	ignoredates=no
	argsnov=${args//v/}
	(( ${#args} - ${#argsnov} == 0 )) || ignoredates=yes

	cmdout=$(PATH= run "${cmd[@]}" 2>&1)
	cmdrv=$?
	if [[ $ignoredates == yes ]]; then
		[[ -z $cmdout ]] && printarg=-n || printarg=
		cmdoutnodates=$(removedates "$cmdout")
		expectedout=$(<"$expectedfile")
		expectedoutnodates=$(removedates "$expectedout")

		diffout=$(diff <(print $printarg -- "$expectedoutnodates") <(print $printarg -- "$cmdoutnodates"))
		diffrv=$?
	else
		[[ -z $cmdout ]] && printarg=-n || printarg=
		diffout=$(diff "$expectedfile" <(print $printarg -- "$cmdout"))
		diffrv=$?
	fi

	if (( diffrv != 0 )); then
		echo "$diffout"
		echo "The above difference is with $expectedfile."
		rv=1
	fi

	# If the value was not set in the tinfo file, then we assume
	# an expected value of 0.
	typeset -n expectedrv="TRV_${action}_${expectednum}"
	[[ ${expectedrv+_} ]] || expectedrv=0
	(( $cmdrv == $expectedrv )) || \
		{ echo "Cmd: ${cmd[@]} Actual rv=$cmdrv Expected rv=$expectedrv"; rv=1; }

	if (( Replace && rv )); then
		vprt1 "REPLACING $expectedfile"
		print -- "$cmdout" > "$expectedfile"
	fi

	return $rv
}

function start_one_iptables_rule
{
	typeset iptablescmd=$1
	typeset chain=$2
	typeset vip=$3
	typeset dscp=$4

	typeset -a cmd

	cmd=( "$iptablescmd" -t $Table -A "$chain" -m dscp --dscp "$dscp" -j DADDR "--set-daddr=$vip" )
	run "${cmd[@]}"

	return $?
}

function stop_one_iptables_rule
{
	typeset iptablescmd=$1
	typeset chain=$2
	typeset vip=$3
	typeset dscp=$4

	typeset -a cmd

	cmd=( "$iptablescmd" -t $Table -D "$chain" -m dscp --dscp "$dscp" -j DADDR "--set-daddr=$vip" )
	run "${cmd[@]}"

	return $?
}

# Start one loopback.
# If lonum is "-", then the request is for an IPv6 loopback.
function start_one_loopback
{
	typeset vip=$1
	typeset lonum=$2

	typeset -a cmd

	if [[ $lonum == - ]]; then
		cmd=( ifconfig lo inet6 add "$vip" )
	else
		cmd=( ifconfig "lo:$lonum" "$vip" netmask 255.255.255.255 )
	fi

	run "${cmd[@]}"

	return $?
}

# Returns the given string ($1) repeated $2 times.
# For example,
#     rptstr = 5
# returns "=====".
function rptstr
{
	(( $2 > 0 )) || return ""
	printf "\\$1%.0s" {1..$2}
}

#
# Generate column strings given the header value (e.g., iptbl) and the
# column value (e.g., mangle, raw).
# The function generates three variables.
#     variable         example
#     ---------------  --------
#     hdr_name         "iptbl "
#     hdr_name_equals  "======"
#     hdr_val          "mangle"
#
function gen_column_strings
{
	typeset hdr=$1
	typeset val=$2
	nameref hdr_name=$3
	nameref hdr_equals_name=$4
	nameref val_name=$5
	nameref val_none=$6

	typeset len maxlen none_str

	maxlen=${#val}
	(( ${#hdr} <= maxlen )) || maxlen=${#hdr}

	# Generate the header.
	len=$(( maxlen - ${#hdr} ))
	(( len >= 0 )) || len=$(( -len ))
	hdr_name=$(printf "$hdr$(rptstr ' ' $len)")

	# Generate a string of "="s the same length as the header.
	hdr_equals_name=$(rptstr = $maxlen)

	# Generate the val column.
	len=$(( maxlen - ${#val} ))
	(( len >= 0 )) || len=$(( -len ))
	val_name=$(printf "$val$(rptstr ' ' $len)")

	# Generate the none_str column.
	none_str="--"
	len=$(( maxlen - ${#none_str} ))
	(( len >= 0 )) || len=$(( -len ))
	val_none=$(printf -- "$none_str$(rptstr ' ' $len)")
}



function expand_templates
{
	nameref tmplts=$1
	typeset table=$2

	typeset daddr_table_file f table_cmt
	typeset iptbl_hdr iptbl_hdr_equals iptbl_none iptbl_val
	typeset ipaddr_hdr ipaddr_hdr_equals ipaddr_none ipaddr_val
	typeset name_hdr name_hdr_equals name_none name_val

	daddr_table_file=/sys/module/xt_DADDR/parameters/table
	if [[ -r "$daddr_table_file" ]]; then
		table_cmt="kmod is loaded, using $daddr_table_file"
	elif egrep -qw "^xt_DADDR" /proc/modules; then
		table_cmt="kmod is loaded, using default"
	else
		table_cmt="kmod is unloaded, using default default"
	fi

	gen_column_strings "iptbl"  "$table"   iptbl_hdr  iptbl_hdr_equals  iptbl_val  iptbl_none
	gen_column_strings "name"   "$Node"    name_hdr   name_hdr_equals   name_val   name_none
	gen_column_strings "ipaddr" "$IpAddr"  ipaddr_hdr ipaddr_hdr_equals ipaddr_val ipaddr_none

	if ip6_disabled; then
		ipv6sed1="/^IPV6ONLY:/d"
		ipv6sed2="s/LOOPBACK/--/"
		ipv6sed3="s/IPTSTATE/--/"
		ipv6sed4="s/STATE/stopped/"
	else
		ipv6sed1="s/^IPV6ONLY://"
		ipv6sed2="s/LOOPBACK/lo/"
		ipv6sed3="s/IPTSTATE/up/"
		ipv6sed4="s/STATE/started/"
	fi

	for f in "${tmplts[@]}"; do
		TmpFiles+=( "$f.$table" )
		sed -e "$ipv6sed1" \
		    -e "$ipv6sed2" \
		    -e "$ipv6sed3" \
		    -e "$ipv6sed4" \
		    -e "s;TABLE_CMT;$table_cmt;" \
		    -e "s/TABLE/$table/" \
		    -e "s/IPTBL_HDR_EQUALS/$iptbl_hdr_equals/" \
		    -e "s/IPTBL_HDR/$iptbl_hdr/" \
		    -e "s/IPTBL_VAL/$iptbl_val/" \
		    -e "s/IPTBL_NONE/$iptbl_none/" \
		    -e "s/IPADDR_HDR_EQUALS/$ipaddr_hdr_equals/" \
		    -e "s/IPADDR_HDR/$ipaddr_hdr/" \
		    -e "s/IPADDR_VAL/$ipaddr_val/" \
		    -e "s/IPADDR_NONE/$ipaddr_none/" \
		    -e "s/NAME_HDR_EQUALS/$name_hdr_equals/" \
		    -e "s/NAME_HDR/$name_hdr/" \
		    -e "s/NAME_VAL/$name_val/" \
		    -e "s/NAME_NONE/$name_none/" \
		    $f.template > $f.$table
	done
}
