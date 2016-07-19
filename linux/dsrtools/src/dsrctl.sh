#!/bin/ksh

ScriptName="${0##*/}"

CacheFile="/var/cache/dsrtools/dsr.cache"
ConfigVariables=
FakeAliasNum=0
GotLoopbacksAlready=0
GotConfAlready=0
GotIptablesAlready=0
NoHeader=no
NoCacheFile=no
CacheFileNeedsRewrite=no

# We keep different maxlens for when we print with the -a option and when we
# just print the configured DSRs.
IPMaxlenAll=0
IPMaxlenConf=0
NameMaxlenAll=0
NameMaxlenConf=0

# All of the information about DSRs we start is kept in Dsr_*
# associative arrays except the Dsr_ip indexed array which is used to
# keep the order of what we start.  The Dsr_ip array element is always
# the first item created when we start DSRs.
#
# The Dsr_* and Iptables_* associative arrays are indexed by "$vip,$dscp".
# The IP is always the numeric version and the DSCP is always decimal.
# If the .conf file provided a hex value for the DSCP, this is kept in
# Dsr_dscp.
# The Lo_* associative arrays are indexed by "$vip".
#
# Note that almost all of the Dsr_* arrays use the numeric IP and the DSCP
# value as the key, not the FQDN and the DSCP value.  The exception is
# Dsr_confip2numericip that is used to convert from the IP given in the config
# file to the numeric IP used as a key for all of the others.  If the config
# file only provides a numeric IP, then the key is the numeric IP.
#
# state (Dsr_state, Lo_state, Iptables_state)
#     init
#     error
#     stopping
#     stopped
#     starting
#     started
#     partial
# type
#     l2dsr
#     l3dsr
#     iptbl (for iptables rules not related to DSR)
#     loopb (for loopbacks not related to DSR)
#
# dsrsrc
#     configured
#     discovered

#
#
# JFYI: This is how we check for existence of an array (indexed or
#       associative) elt in ksh/bash.
#           [ ${arr[key]+_} ]   || echo "notfound"
#           [ ! ${arr[key]+_} ] || echo "found"
#

typeset -a Dsr_ip_dscp
typeset -A Dsr_state			# current state of DSR
typeset -A Dsr_indx			# indx of this DSR
typeset -A Dsr_type			# type of DSR: l3dsr, l2dsr
typeset -A Dsr_name			# configured VIP (numeric or fqdn)
typeset -A Dsr_dscp			# configured DSCP value
typeset -A Dsr_dsrsrc			# source of this DSR
typeset -A Dsr_config_file		# where this DSR was configured
typeset -A Dsr_config_file_lineno	# line number is this DSR in .conf file
typeset -A Dsr_confip2numericip		# convert from .conf VIP to numeric VIP

typeset -a Lo_ip
typeset -A Lo_state
typeset -A Lo_state_orig
typeset -A Lo_indx
typeset -A Lo_num
typeset -A Lo_losrc

typeset -a Iptables_ip_dscp
typeset -A Iptables_state
typeset -A Iptables_state_orig
typeset -A Iptables_indx
typeset -A Iptables_dscp
typeset -A Iptables_iptsrc

Usage=$(cat <<EOF
Usage: $ScriptName [-d <configdir>] [-f <configfile>] [-ahv] <action>
       -a       For status, print status for all discovered loopbacks
                and iptables rules, not just configured dsrs.
       -d dir   Specify dsr config directory.  Defaults to /etc/dsr.d.
       -f file  Read a single dsr config from this file.
                The -d option is ignored if -f is used.
       -h       Print a usage statement and exit.
       -n       Don't actually perform the operations.  This option
                is useful with the verbose option.
       -v       Be verbose.  More -v options get more verbose output.
       -x       Don't print the header.
       <action> Run the requested action.  Supported actions are:
                check
		restart
		status
                start
                stop
EOF
)

# Print the cmd ($@) according to VerboseLevel.
#     VerboseLevel==0: don't echo the cmd
#     VerboseLevel==1: echo the cmd
#     VerboseLevel>=2: echo the curdate and cmd
# The first arg is always the verboselevel limit.
# If $VerboseLevel <= $vlevel, then the remaining arguments are not printed.
function vprt
{
	typeset vlevel
	typeset curdate

	vlevel="$1"
	shift

	[ $VerboseLevel -ge $vlevel ] || return 0
	[ $VerboseLevel -lt 2 ] || curdate="$(date +%Y%m%d-%H:%M:%S): "
	echo "$curdate$@" >&3
}

# For convenience.
function vprt1 { vprt 1 "$@"; }
function vprt2 { vprt 2 "$@"; }
function vprt3 { vprt 3 "$@"; }
function vprt4 { vprt 4 "$@"; }
function vprt5 { vprt 5 "$@"; }

function vrun
{
	typeset vlevel="$1"
	typeset rv=0

	shift

	vprt $vlevel "+$@"
	[ $NoRun == yes ] || "$@" || rv=$?
	[ $rv -eq 0 ] || vprt $vlevel "FAILED (rv=$rv): $@"

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
        # We default the verbose level to 1 for printing commands.
	vrun1 "$@"
}

# This function exits if the caller is not root.
function check_root
{
	if [ $(id -u) != "0" ]; then
		echo "You must be root to run this command." >&2
		exit 1
	fi
}

#
# The given IP address is a FQDN.  Convert it to an IPv4 dotted decimal
# address and return it.  If the name can't be converted, then return
# "notfound".
#
function _fqdn_to_ipv4_addr
{
	typeset fqdn="$1"

	typeset cmd ipaddrs numericip oifs
	typeset -a numericips

	# $? is the return value of the rightmost cmd that fails or zero otherwise.
	# This is usually the egrep.
	ipaddrs=$(run getent ahosts "$fqdn" | run grep STREAM | run awk '{print $1}')
	[ $? -eq 0 ] || return 1

	oifs="$IFS"
	IFS=$'\n' numericips=( $(echo "$ipaddrs") )
	IFS="$oifs"

	for numericip in "${numericips[@]}"
	do
		case "$numericip" in
		  [0-9]*.[0-9]*.[0-9]*.[0-9]*)
			echo "$numericip"
			return 0
			;;
		esac
	done

	echo "notfound"

	return 0
}

# Returns
#   0 if the given address is an IPv4 address
#   1 if the given address is an IPv6 address
function _ipv4addr
{
	case "$1" in
	  *:*)  return 1;;
	  *)    return 0;;
	esac
}

# Returns the address family (4/6) based on IP address.
# Defaults to IPv4.
function _addraf
{
	typeset vip="$1"
	typeset af

	af=4
	_ipv4addr "$vip" || af=6

	echo "$af"
}

# Given the VIP and DSCP, convert them into a key used for all
# of the associative arrays (Dsr_*, Iptables_*).
function makekey
{
	typeset vip="$1"
	typeset dscp="$2"

	echo "$vip,$dscp"
}

function cvt2dec
{
	echo $(("$1"))
}

# Check whether the argument is numeric.  We accept decimal,
# octal, and hex values.  No fractions are accepted and neither
# are plus/minus.
# This function works back to ksh93.
function isnumeric
{
	case "$1" in
	  0)			return 0;;	# decimal
	  +([1-9])*([0-9]))	return 0;;	# decimal
	  0[xX]+([0-9a-fA-F]))	return 0;;	# hex
	  0+([0-9]))		return 0;;	# octal
	esac

	return 1
}


function _emit_data
{
	typeset dsrtype="$1"
	typeset state="$2"
	typeset name="$3"
	typeset vip="$4"
	typeset dscp="$5"
	typeset loopback="$6"
	typeset iptables="$7"
	typeset src="$8"

	typeset ipmaxlen namemaxlen out

	if [ $AllOpt -eq 0 ]; then
		namemaxlen=$NameMaxlenConf
		ipmaxlen=$IPMaxlenConf
	else
		namemaxlen=$NameMaxlenAll
		ipmaxlen=$IPMaxlenAll
	fi

	[ "$dsrtype" != "=" ]  || dsrtype=$(_Dsr_header_sep 5)
	[ "$state" != "=" ]    || state=$(_Dsr_header_sep 7)
	[ "$name" != "=" ]     || name=$(_Dsr_header_sep $namemaxlen)
	[ "$vip" != "=" ]      || vip=$(_Dsr_header_sep $ipmaxlen)
	[ "$dscp" != "=" ]     || dscp=$(_Dsr_header_sep 4)
	[ "$loopback" != "=" ] || loopback=$(_Dsr_header_sep 8)
	[ "$iptables" != "=" ] || iptables=$(_Dsr_header_sep 8)
	[ "$src" != "=" ]      || src=$(_Dsr_header_sep 4)

	if [ $AllOpt -eq 0 ]; then
		out=$(printf "%-5s %-7s %-${namemaxlen}s  %-${ipmaxlen}s  %-4s %-8s %-8s\n" \
			"$dsrtype" \
			"$state" \
			"$name" \
			"$vip" \
			"$dscp" \
			"$loopback" \
			"$iptables" | \
		      sed -e 's/[ ]*$//')
	else
		out=$(printf "%-5s %-7s %-${namemaxlen}s  %-${ipmaxlen}s  %-4s %-8s %-8s %-4s\n" \
			"$dsrtype" \
			"$state" \
			"$name" \
			"$vip" \
			"$dscp" \
			"$loopback" \
			"$iptables" \
			"$src" | \
		      sed -e 's/[ ]*$//')
	fi

	echo "$out"
}

# =======================================================================
# Dsr
# =======================================================================

#
# Determine what kind of IP address we have and then initialize the given DSR
# entry.  The Dsr_* data structures remain unchanged if the new DSR conflicts.
#
function _Dsr_init
{
	typeset dsrsrc="$1"
	typeset vip="$2"
	typeset dscp="$3"
	typeset config_file="$4"
	typeset lineno="$5"

	typeset fqdn indx key numericip dscp_dec

	# We accept both FQDN names and numeric IPs.
	#
        # If we get a FQDN, then it is used, by historical convention, only
        # for the IPv4 address even if an IPv6 address exists for the FQDN.
	#
        # You can still have an IPv6 address, but it must be given as an IPv6
        # address.
	case "$vip" in
	  [0-9]*.[0-9]*.[0-9]*.[0-9]*)
		# IPv4 address
		numericip="$vip"
		fqdn="$vip"
		;;
	  *:*)
		# IPv6 address
		numericip="$vip"
		fqdn="$vip"
		;;
	  *)
		# FQDN
		numericip=$(_fqdn_to_ipv4_addr "$vip" 2>&1)
		[ $? -eq 0 ] || { echo "$numericip"; return 1; }

		if [ "$numericip" == "notfound" ]; then
			echo "Cannot convert fqdn \"$vip\" to an IPv4 address."
			return 1
		fi

		fqdn="$vip"
		;;
	esac

	[ -z "$dscp" ] && dscp_dec= || dscp_dec=$(cvt2dec "$dscp")

	_Dsr_validate_dsr "$fqdn" "$numericip" "$dscp" "$config_file" "$lineno" ||
		{ [ $? -eq 1 ] && return 0 || return $?; }

	# Now we create a new Dsr.
	indx=${#Dsr_ip_dscp[@]}

	[ ${#numericip} -le $IPMaxlenConf ] || IPMaxlenConf=${#numericip}
	[ ${#numericip} -le $IPMaxlenAll ]  || IPMaxlenAll=${#numericip}
	[ ${#fqdn} -le $NameMaxlenConf ]    || NameMaxlenConf=${#fqdn}
	[ ${#fqdn} -le $NameMaxlenAll ]     || NameMaxlenAll=${#fqdn}

	key=$(makekey "$numericip" "$dscp_dec")
	Dsr_ip_dscp[$indx]="$key"
	Dsr_indx[$key]="$indx"
	Dsr_state[$key]="init"
	Dsr_dscp[$key]="$dscp"
	Dsr_dsrsrc[$key]="$dsrsrc"
	Dsr_name[$key]="$fqdn"

	Dsr_confip2numericip[$key]="$numericip"
	key2=$(makekey "$fqdn" "$dscp_dec")
	[ ${Dsr_confip2numericip[$key2]+_} ] || Dsr_confip2numericip[$key2]="$numericip"

	[ -n "$dscp" ] &&
		Dsr_type[$key]="l3dsr" ||
		Dsr_type[$key]="l2dsr"

	Dsr_config_file[$key]="$config_file"
	Dsr_config_file_lineno[$key]="$lineno"

	return 0
}

#
# Read the dsr configuration file.
#
function _Dsr_read_config_file
{
	typeset config_file="$1"

	typeset confout dscp dscp_dec vip key line lines lineno name oifs rv=0

	lines=$(run cat "$config_file" || rv=$?)
	[ $rv -eq 0 ] || { echo "Can't read $config_file."; return 1; }

	lineno=0
	while read line; do
		((lineno++))

		# These cmds are rarely interesting, so you have to request a
		# higher VerboseLevel to get them to print.
		line=$(vrun5 echo "$line" | \
		       vrun5 sed -e '/^[ \t]*#/d' -e 's/[ \t]*#.*//' -e '/^[ \t]*$/d' -e 's/[ \t]*//g')
		[ $? -eq 0 ] || return 1

		[ -n "$line" ] || continue;

		case "$line" in
		  Version*)
			# This is an ordinary variable line.
			name=${line%%=*}
			eval "$name=\"${line##$name=}\""
			;;
		  *)
			# This is a DSR line.
			vip=${line%%=*}
			case "$line" in
			  *=*)  dscp=${line##$vip=};;
			  *)    dscp=;;
			esac

			_Dsr_init "configured" "$vip" "$dscp" "$config_file" "$lineno" ||
				{ rv=1; continue; }

			[ -z "$dscp" ] && dscp_dec= || dscp_dec=$(cvt2dec "$dscp")
			key=$(makekey "$vip" "$dscp_dec")
			_Lo_init "configured" "${Dsr_confip2numericip[$key]}" "" || rv=1

			[ -z "$dscp" ] ||
				_Iptables_init "configured" \
				               "${Dsr_confip2numericip[$key]}" \
				               "$dscp" || rv=1

			;;
		esac
	done < <(echo "$lines")

	return $rv
}

#
# Read the configuration file and place the variables defined there into the
# environment.
# Look first for $ConfigFile.  It it's provided, then only work with that file.
# If there is no $ConfigFile, then look in $ConfigDir and load all of the
# *.conf files there.
#
function _Dsr_read_configuration
{
	typeset f oifs rv=0 v
	typeset -a files

	[ $GotConfAlready -eq 0 ] || return 0

	GotConfAlready=1

	if [ -n "$ConfigFile" ]; then
		[ -r "$ConfigFile" ] || \
			{ echo "Cannot find the configuration file ($ConfigFile)."; return 1; }

		vprt2 "===== Loading config file $ConfigFile"
		_Dsr_read_config_file "$ConfigFile" || return 1
	else
		if [ ! -d "$ConfigDir" ]; then
			echo "Cannot find the configuration directory ($ConfigDir)."
			return 0
		fi

		oifs="$IFS"
		IFS=$'\n' files=( $(run find -L "$ConfigDir" -type f -name \*.conf | run sort) )
		rv=$?
		IFS="$oifs"
		[ $rv -eq 0 ] || \
			{ echo "Cannot get file list from $ConfigDir."; return 1; }

		for f in "${files[@]}"; do
			vprt2 "===== Loading config file $f"
			_Dsr_read_config_file "$f" || return 1
		done
	fi

	# Ensure that we have set all of the package variables that we'll be using.
	for v in $ConfigVariables; do
		if ! (eval echo \${$v?} > /dev/null 2>&1); then
			echo "Failed to set all configuration variables."
			echo "Variable \"$v\" not found."
			return 1
		fi
	done

	return 0
}
function _Dsr_header_sep
{
	typeset i="$1"
	typeset out=

	for ((; i>0; i--)) do
		out+="="
	done

	printf "$out"
}

function _Dsr_print_dsr_header
{
	_emit_data "type" "state" "name" "ipaddr" "dscp" "loopback" "iptables" "src"
	_emit_data "=" "=" "=" "=" "=" "=" "=" "="
}

function _Dsr_calculate_state
{
	typeset vip="$1"
	typeset dscp="$2"

	typeset startedcnt=0 state

	key=$(makekey "$vip" "$dscp")
	if _Dsr_l3dsr "$vip" "$dscp"; then
		[ "${Lo_state[$vip]}" != "started" ] || (( startedcnt++ )) || true
		[ "${Iptables_state[$key]}" != "started" ] || (( startedcnt++ )) || true

		case "$startedcnt" in
		  0)   state="stopped";;
		  1)   state="partial";;
		  2)   state="started";;
		  *)   state="error";;
		esac
	else
		state="stopped"
		[ "${Lo_state[$vip]}" != "started" ] || state="started"
		[ "${Iptables_state[$key]}" != "started" ] || state="error"
	fi

	echo "$state"
}

function _Dsr_update_state
{
	typeset dscp i vip key

	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")
		Dsr_state[$key]=$(_Dsr_calculate_state "$vip" "$dscp")
	done
}

function _Dsr_init_discovered_dsrs
{
	typeset dscp i vip key

	for ((i=0; i<${#Iptables_ip_dscp[@]}; i++)) do
		vip=${Iptables_ip_dscp[$i]%%,*}
		dscp=${Iptables_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		! _Dsr_is_configured_dsr "$vip" "$dscp" || continue
		[ "${Iptables_iptsrc[$key]}" == "discovered" ] || continue
		[ ${Lo_indx[$vip]+_} ] || continue
		[ "${Lo_losrc[$vip]}" == "discovered" ] || continue

		_Dsr_init "discovered" "$vip" "$dscp" "none" "none" ||
				{ rv=1; continue; }
	done
}

#
# Print a single DSR given its indx into Dsr_ip.
#
function _Dsr_print_one_dsr
{
	typeset i="$1"

	typeset af dscp vip iptout key l3dsr loout src state dsrtype

	vip=${Dsr_ip_dscp[$i]%%,*}
	dscp=${Dsr_ip_dscp[$i]##*,}
	key=$(makekey "$vip" "$dscp")
	af=$(_addraf "$vip")

	vprt2 "====== Checking configured DSR $vip=${Dsr_dscp[$key]}"

	if [ "${Lo_state[$vip]}" == "started" ]; then
		[ "$af" == "4" ] || loout="lo"
		[ "$af" == "6" ] || loout="lo:${Lo_num[$vip]}"
	else
		loout="--"
	fi

	[ "${Iptables_state[$key]}" == "started" ] || iptout="--"
	[ "${Iptables_state[$key]}" != "started" ] || iptout="up"

	[ "${Dsr_dsrsrc[$key]}" == "configured" ] || src="disc"
	[ "${Dsr_dsrsrc[$key]}" != "configured" ] || src="conf"

	state=$(_Dsr_calculate_state "$vip" "$dscp")
	if _Dsr_l3dsr "$vip" "$dscp"; then
		dsrtype="l3dsr"

		# We always print the value provided in the .conf
		# file, not any possible conversion to decimal.
		dscp="${Dsr_dscp[$key]}"
	else
		dsrtype="l2dsr"
		dscp="--"
	fi
	_emit_data "$dsrtype" \
		   "$state" \
		   "${Dsr_name[$key]}" \
		   "$vip" \
		   "$dscp" \
		   "$loout" \
		   "$iptout" \
		   "$src"

	return 0
}

#
# If something goes wrong while starting the DSRs, we need to undo (stop)
# all of the DSRs we just started.  This function does that cleanup.
#
function _Dsr_restore_dsrs_to_orig_state
{
	typeset dscp i vip key save_nofail

	_Lo_reread_loopbacks
	_Iptables_reread_iptables

	# We try as hard as we can to stop the DSRs even if we have
	# some failures.
	save_nofail="$NoFail"
	No_Fail=1

	# Remove all of the DSRs that we started.
	#
	for ((i=${#Dsr_ip_dscp[@]}-1; i>=0; i--)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

                # Skip DSRs that weren't read from the config files because if
                # they didn't come from the config files, then we didn't start
                # them.
		[ ${Dsr_dsrsrc[$key]} == "configured" ] || continue

		vprt2 "====== Restoring DSR $vip"

		_Iptables_restore_orig_state "$vip" "$dscp"
		_Lo_restore_orig_state "$vip"
	done

	NoFail="$save_nofail"

	return 0
}
#
# Returns
#   0 if the given ipaddr refers to an L3DSR DSR
#   1 if the given ipaddr refers to an L2DSR DSR
#
function _Dsr_l3dsr
{
	typeset vip="$1"
	typeset dscp="$2"

	typeset key

	key=$(makekey "$vip" "$dscp")
	[ "${Dsr_type[$key]}" != "l3dsr" ] || return 0
	return 1
}

# Returns count of configured IPv6 DSRs.
function _Dsr_configured_ipv6_dsr_count
{
	typeset i vip dscp ipv6dsrs=0

	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}

		_Dsr_ip_exists "$vip" "$dscp" "$i" || continue
		_Dsr_is_configured_dsr "$vip" "$dscp" || continue
		_ipv4addr "$vip" || continue

		((ipv6dsrs++))
	done

	echo "$ipv6dsrs"
}

# Returns count of configured DSRs (both IPv4 and IPv6).
function _Dsr_configured_dsr_count
{
	typeset i vip dscp dsrcount=0

	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}

		_Dsr_ip_exists "$vip" "$dscp" "$i" || continue
		_Dsr_is_configured_dsr "$vip" "$dscp" || continue

		((dsrcount++))
	done

	echo "$dsrcount"
}

#
# Validate a DSCP value.  If the DSCP value is invalid, the reason is printed.
# Returns
#   0 if the DSCP value is valid
#   1 if the DSCP value is invalid
#
function _Dsr_validate_dscp
{
	typeset dscp="$1"
	typeset config_file="$2"
	typeset lineno="$3"

	typeset str rv=0

	# Empty DSCPs just mean L2DSR, so they're valid.
	[ -n "$dscp" ] || return 0

	# First, test if dscp is numeric.
	if isnumeric "$dscp"; then
		if [ $(cvt2dec "$dscp") -gt 63 ]; then
			str="Invalid DSCP value at $config_file, line $lineno.  "
			str+="\"$dscp\" too large."
			echo "$str"
			rv=1
		fi
	else
		str="Invalid DSCP value at $config_file, line $lineno.  "
		str+="\"$dscp\" is not an integer."
		echo "$str"
		rv=1
	fi

	return $rv
}

# Validate the DSR.
# Returns 0 if everything was OK.
# Returns 1 if duplicate DSRs are found.
# Returns 2 otherwise.
function _Dsr_validate_dsr
{
	typeset fqdn="$1"
	typeset vip="$2"
	typeset dscp="$3"
	typeset config_file="$4"
	typeset lineno="$5"

        typeset af dscp_dec dupindx dupip dupdsrtype dupdscp key previp
        typeset prevdsrtype prevdscp

	_Dsr_validate_dscp "$dscp" "$config_file" "$lineno" || return 2

	key=$(makekey "$vip" "$dscp")

	dupindx=$(_Dsr_find_configured_dsr_by_ip_and_dscp "$vip" "$dscp")
	if [ "$dupindx" != "notfound" ]; then
		# We have found an exact duplicate.
                echo "Duplicate DSRs found for $vip."
                _Dsr_l3dsr "$vip" "$dscp" && dupdsrtype="L3DSR" || dupdsrtype="L2DSR"

                str="- Prev: $dupdsrtype at "
                str+="${Dsr_config_file[$key]}, "
                str+="line ${Dsr_config_file_lineno[$key]}."
                echo "$str"

                str="- Dup:  $dupdsrtype at $config_file, line $lineno."
                echo "$str"

                return 1
	fi

	# Check for DSRs that have the same DSCP, but a different IP.
	af=$(_addraf "$vip")
	dupindx=$(_Dsr_find_configured_dsr_by_dscp "$dscp" "$af")
	if [ "$dupindx" != "notfound" ]; then
		previp=${Dsr_ip_dscp[$dupindx]%%,*}

		if [ -z "$dscp" ]; then
			dupdsrtype="L2DSR"
			dupdscp="none"
		else
			dupdsrtype="L3DSR"
			dupdscp="$dscp"
		fi

		# Prev: L3DSR  Dup: L3DSR (diff IPs)
		# Prev: L2DSR  Dup: L2DSR (diff IPs)
		prevdsrtype="$dupdsrtype"
		prevdscp="$dupdscp"

		str="Conflicting DSRs "
		str+="(IP=$previp, IP=$vip) "
		str+="found with DSCP $prevdscp."
		echo "$str"

		dscp_dec=$(cvt2dec $dscp)
		str="- Prev: $prevdsrtype at ${Dsr_config_file[$previp,$dscp_dec]}, "
		str+="line ${Dsr_config_file_lineno[$previp,$dscp_dec]}."
		echo "$str"

		str="- Dup:  $dupdsrtype at $config_file, line $lineno."
		echo "$str"

		return 2
	fi

	return 0
}

# Return 0 if $vip exists and is equal to the given indx.
# Otherwise, return 1.
function _Dsr_ip_exists
{
	typeset vip="$1"
	typeset dscp="$2"
	typeset indx="$3"

	typeset key

	key=$(makekey "$vip" "$dscp")
	[ ! ${Dsr_indx[$key]+_} ] || [ "${Dsr_indx[$key]}" != "$indx" ] || \
		return 0

	return 1
}

# Return 0 if $vip is a configured DSR.
function _Dsr_is_configured_dsr
{
	typeset vip="$1"
	typeset dscp="$2"

	typeset key

	key=$(makekey "$vip" "$dscp")
	[ ! ${Dsr_dsrsrc[$key]+_} ] || [ "${Dsr_dsrsrc[$key]}" != "configured" ] || \
		return 0

	return 1
}

# Return 0 if $dscp is a valid DSCP for $vip.
function _Dsr_dscp_matches
{
	typeset vip="$1"
	typeset dscp="$2"
	typeset indx="$3"

	typeset key

	key=$(makekey "$vip" "$dscp")
	[ ${Dsr_indx[$key]+_} ] || return 1
	[ ${Dsr_dscp[$key]+_} ] || return 1
	[ "${Dsr_indx[$key]}" == "$indx" ] || return 1
	[ "${Dsr_dscp[$key]}" == "$dscp" ] || return 1

	return 0
}

function _Dsr_find_configured_dsr_by_ip_and_dscp
{
	typeset vip="$1"
	typeset dscp="$2"

	typeset found i

	found=notfound
	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		_Dsr_ip_exists "$vip" "$dscp" "$i" || continue
		_Dsr_is_configured_dsr "$vip" "$dscp" || continue
		_Dsr_dscp_matches "$vip" "$dscp" "$i" || continue

		found="$i"
		break
	done

	echo "$found"

	return 0
}

# Search for just the DSCP value in the configured
# DSRs.  We use this to search for duplicate DSCPs in
# the config files.
# Don't bother to search for L2DSRs -- they all have an
# empty DSCP.
function _Dsr_find_configured_dsr_by_dscp
{
	typeset dscparg="$1"
	typeset afarg="$2"

	typeset dscp found i vip key

	[ -n "$dscparg" ] || { echo notfound; return 0; }

	found=notfound
	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		[ "${Dsr_dsrsrc[$key]}" == "configured" ] || continue
		[ $(cvt2dec "$dscp") -eq $(cvt2dec "$dscparg") ] || continue
		[ "$afarg" == $(_addraf "$vip") ] || continue

		[ "$found" == "notfound" ] || break
		found="$i"
	done

	echo "$found"

	return 0
}

# Search for just the VIP address in the configured DSRs.
# This funtion only finds the first matching entry.
function _Dsr_find_discovered_dsr_by_vip
{
	typeset viparg="$1"

	typeset dscp found i vip key

	[ -n "$viparg" ] || { echo notfound; return 0; }

	found=notfound
	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		[ "${Dsr_dsrsrc[$key]}" == "discovered" ] || continue
		[ "$viparg" == "$vip" ] || continue

		found="$i"
		break
	done

	echo "$found"

	return 0
}

function _Dsr_dbg_print
{
	typeset af dscp i vip key state dsrsrc dsrcount

	_Dsr_read_configuration || return 1

	vprt2 "====== Config File Start"
	vprt2 "======     Number of DSRs = $(_Dsr_configured_dsr_count)"
	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		[ ${Dsr_dsrsrc[$key]} == "configured" ] || continue

		af=$(_addraf "$vip")
		state=${Dsr_state[$key]}
		dsrsrc=${Dsr_dsrsrc[$key]}
		dscp=${Dsr_dscp[$key]}
		vprt2 "======         dsr$af: $dsrsrc $state vip=$vip dscp=$dscp"
	done

	vprt2 "====== Config File End"

	return 0
}

# =======================================================================
# End of Dsr
# =======================================================================


# =======================================================================
# Cache
# =======================================================================

#
# Add a cache entry.
#
function _Cache_init
{
	typeset dsrsrc="$1"
	typeset vip="$2"
	typeset dscp="$3"
	typeset config_file="$4"
	typeset lineno="$5"

	typeset fqdn indx key numericip

	# Unlike regular configuration elements, the vip from the cache
	# file is always numeric.
	numericip="$vip"
	fqdn="$vip"

	# If it already exists, then we have a corrupted cache file.
	[ ! ${Cache_ip_dscp[$numericip]+_} ] || { CacheFileNeedsRewrite=yes; return 1; }

	# Now create the new cache entry.
	indx=${#Cache_ip_dscp[@]}

	[ ${#numericip} -le $Cache_ip_maxlen ] || Cache_ip_maxlen=${#numericip}
	[ ${#fqdn} -le $Cache_name_maxlen ] || Cache_name_maxlen=${#fqdn}

	key=$(makekey "$numericip" "$dscp")
	Cache_ip_dscp[$indx]="$numericip"
	Cache_indx[$key]="$indx"
	Cache_state[$key]="init"
	Cache_dsrsrc[$key]="$dsrsrc"
	Cache_name[$key]="$fqdn"
	Cache_conf_dsr_found[$key]="no"

	if [ -n "$dscp" ]; then
		Cache_type[$key]="l3dsr"
	else
		Cache_type[$key]="l2dsr"
	fi

	Cache_config_file[$key]="$config_file"
	Cache_config_file_lineno[$key]="$lineno"

	indx=$(_Dsr_find_configured_dsr_by_ip_and_dscp "$vip" "$dscp")
	if [ "$indx" != "notfound" ]; then
		Cache_conf_dsr_found[$key]="yes"
	fi

	return 0
}

#
# Read the cached dsr configuration file.
#
# Returns
#     0 if we successfully read the file
#     1 if not
#
function _Cache_read_file
{
	typeset cache_file="$CacheFile"
	typeset dscp vip line lineno lines rv=0

	# If there's no cache file, then that's ok.
	# Just return with success.
	[ -r "$cache_file" ] || { NoCacheFile="yes"; return 0; }

	lines=$(cat "$cache_file" || rv=$?)
	[ $rv -eq 0 ] || { echo "Can't read $cache_file."; return 1; }

	lineno=0
	while read line; do
		((lineno++))

		# These cmds are rarely interesting, so you have to request a
		# higher VerboseLevel to get them to print.
		line=$(vrun5 echo "$line" | \
		       vrun5 sed -e '/^[ \t]*#/d' -e 's/[ \t]*#.*//' -e '/^[ \t]*$/d' -e 's/[ \t]*//g')
		[ $? -eq 0 ] || return 1

		[ -n "$line" ] || continue;

		# This is a DSR line.
		# The vip in a cache file is always numeric.
		vip=${line%%=*}
		case "$line" in
		  *=*)  dscp=${line##$vip=};;
		  *)    dscp=;;
		esac

		_Cache_init "cached" "$vip" "$dscp" "$cache_file" "$lineno" || rv=1

	done < <(echo "$lines")

	return $rv
}

# Compare the cached configuration with the configuration we read.
# Returns
#     0 if the configuration and its cached version are the same
#       Note that they are the same if both are empty.
#     1 if not
function _Cache_compare_config
{
	typeset dscp i vip key

	# Nonexistent cache files fail the comparison test.
	[ "$NoCacheFile" == "no" ] || return 1

	# They are different if the number of entries is different.
	[ ${#Dsr_ip_dscp[@]} -eq ${#Cache_ip_dscp[@]} ] || return 1

        # Compare the entries one by one.  Return failure if there are any
        # differences.
	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		[ "${Cache_indx[$key]}+_" ] || return 1
	done

	return 0
}

function _Cache_write
{
	typeset dscp i vip

	# There is no need to write it out if the configuration hasn't
	# changed.
	[ $CacheFileNeedsRewrite == yes ] || return 0

        # Compare the configuration with the cached version.  If they are
        # the same (including both empty), then there's nothing to do.
	! _Cache_compare_config || return 0

	[ -w "$CacheFile" ] ||
		{ echo "The cache file ($CacheFile) is not writable."; return 1; }

	vrun5 echo "# dsrtool cached configuration" > "$CacheFile"
	vrun5 echo "# written on $(date)" >> "$CacheFile"

	for ((i=0; i<${Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		[ -z "$dscp" ] || vrun5 echo "$vip=$dscp" >> "$CacheFile"
		[ -n "$dscp" ] || vrun5 echo "$vip"       >> "$CacheFile"
	done

	CacheFileNeedsRewrite=no
}

function _Cache_dbg_print
{
	typeset af dscp i vip key dsrsrc dsrcount state

	_Cache_read_file || return 1

	vprt2 "====== Cache File Start"
	vprt2 "======     Number of DSRs = ${#Cache_ip_dscp[@]}"
	for ((i=0; i<${#Cache_ip[@]}; i++)) do
		vip=${Cache_ip_dscp[$i]%%,*}
		dscp=${Cache_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		af=$(_addraf "$vip")
		state=${Cache_state[$key]}
		dsrsrc=${Cache_dsrsrc[$key]}
		vprt2 "======         dsr$af: $dsrsrc $state vip=$vip dscp=$dscp"
	done

	vprt2 "====== Cache File End"

	return 0
}

# =======================================================================
# End of Cache
# =======================================================================


# =======================================================================
# Lo
# =======================================================================

function _Lo_init
{
	typeset losrc="$1"
	typeset vip="$2"
	typeset lonum="$3"

	typeset indx

	# Now we create a new Loopback.
	indx=${#Lo_ip[@]}

	Lo_ip[$indx]="$vip"
	Lo_indx[$vip]="$indx"
	Lo_state[$vip]="init"
	Lo_state_orig[$vip]="init"
	Lo_losrc[$vip]="$losrc"
	Lo_num[$vip]="$lonum"

	return 0
}

#
# Start a loopback.
#
# Returns
#   0 if the loopback was successfully started
#   1 otherwise
#
function _Lo_start
{
	typeset vip="$1"

	typeset af aliasincrement lonum rv=0

	[ "${Lo_state[$vip]}" == "stopped" ] || return 0

	Lo_state[$vip]="starting"

	if [ $NoRun == yes ]; then
		(( FakeAliasIncrement++ ))
		aliasincrement=$FakeAliasIncrement
	else
		aliasincrement=0
	fi

	lonum=$(_Lo_get_loopback_alias "$aliasincrement" || rv=$?)
	if [ $rv -ne 0 ]; then
		Lo_state[$vip]="error"
		echo "Cannot find available loopback alias."
		return 1
	fi

	Lo_num[$vip]="$lonum"

	af=$(_addraf "$vip")
	[ "$af" == "4" ] || cmd="ifconfig lo inet6 add $vip/128"
	[ "$af" == "6" ] || cmd="ifconfig lo:$lonum $vip netmask 255.255.255.255"

	if run $cmd; then
		Lo_state[$vip]="started"
		rv=0
	else
		Lo_state[$vip]="error"
		unset Lo_num[$vip]
		echo "Failed to start loopback for $vip."
		rv=1
	fi

	return $rv
}

#
# Stop a loopback.
#
# Returns
#   0 if the loopback was successfully stopped
#   1 otherwise
#
function _Lo_stop
{
	typeset vip="$1"

	typeset af cmd rv

	[ "${Lo_state[$vip]}" == "started" ] || return 0

	Lo_state[$vip]="stopping"

	af=$(_addraf "$vip")
	[ "$af" == "4" ] || cmd="ifconfig lo inet6 del $vip/128"
	[ "$af" == "6" ] || cmd="ifconfig lo:${Lo_num[$vip]} down"

	if run $cmd; then
		Lo_state[$vip]="stopped"
		rv=0
	else
		Lo_state[$vip]="error"
		rv=1
	fi

	return $rv
}

function _Lo_restore_orig_state
{
	typeset vip="$1"

	if [ "${Lo_state_orig[$vip]}" == "stopped" ]; then
		[ "${Lo_state[$vip]}" != "started" ] || _Lo_stop "$vip"
	fi
	if [ "${Lo_state_orig[$vip]}" == "started" ]; then
		[ "${Lo_state[$vip]}" != "stopped" ] || _Lo_start "$vip"
	fi
}

#
# Find an unused loopback alias.
#
# Reread the loopback information and then iterate through the loopbacks
# we found for the max loopback alias.  Since we're looking for the next
# available loopback alias, we just add 1 to the max.
#
# Most of the time, the aliases are sequential, but there is no guarantee.
#
# If we're not running commands, then just create fake, but reasonable,
# numbers.  This is controlled by the aliasincrement.  It's 0 when we're
# running commands and artifically increases when we're not.
#
# Returns
#   0 if no failures were found
#     Prints the max alias value
#   1 if we failed to successfully read the loopback information
#     Prints nothing
#
function _Lo_get_loopback_alias
{
	typeset aliasincrement="$1"

	typeset i vip max newalias

	_Lo_reread_loopbacks || return 1

	max=0
	for ((i=0; i<${#Lo_ip[@]}; i++)) do
		vip=${Lo_ip[$i]}
		[ "${Lo_state[$vip]}" == "started" ] || continue

		# IPv6 loopback aliases don't have a lonum value
		# so we check for empty values and skip the max
		# calculation for IPv6 loopback aliases.
		[ ! ${Lo_num[$vip]+_} ] || \
		{ [ $(_addraf "$vip") == "6" ] && [ -z ${Lo_num[$vip]} ]; } || \
		[ ${Lo_num[$vip]} -le $max ] || \
			max=${Lo_num[$vip]}
	done

	[ $NoRun == yes ] || (( max++ ))

	(( newalias = max + aliasincrement )) || true
	echo "$newalias"

	return 0
}

#
# Get all of the loopbacks running on the machine and fill in state
# information if they are configured DSRs.  This works for both IPv4 and IPv6
# loopbacks.
#
function _Lo_get_loopbacks
{
	typeset cmd i indx ipout lines lo loaf loinfo loname lonum vip vipinfo

	[ $GotLoopbacksAlready -eq 0 ] || return 0

	GotLoopbacksAlready=1

	# Run the vip program to get the loopback information.
	# $? is the return value of the rightmost cmd that fails or zero otherwise.
	# This is usually the egrep.
	ipout=$(run ip -o addr show lo | run tr -d \\134 | run egrep -v "127.0.0.1|LOOPBACK|::1/128")
	[ $? -lt 2 ] || return 1

	OIFS="$IFS"
	IFS=$'\n' lines=( $(echo "$ipout") )
	IFS="$OIFS"

	# Expecting output like this from the ip cmd.
	#     1: lo    inet 188.125.67.68/32 brd 188.125.67.68 scope global lo:1
	#     1: lo    inet 188.125.82.253/32 brd 188.125.82.253 scope global lo:2
	#     1: lo    inet 188.125.82.38/32 brd 188.125.82.38 scope global lo:3
	#     1: lo    inet 188.125.82.196/32 brd 188.125.82.196 scope global lo:4
	#
	# It's a little different for RHEL7.
	#     1: lo    inet 188.125.67.68/32 scope global lo:1\ valid_lft forever preferred_lft forever

	for line in "${lines[@]}"; do
                lo=($line)
		loaf=${lo[2]}
		if [ "$loaf" == "inet" ]; then
			# Find the "scope" element.  The loopback name is
			# two elements later.
			indx=-1
			for ((i=0; i<${#lo[@]}; i++)) do
				[ "${lo[$i]}" == "scope" ] || continue

				(( indx = i + 2 ))
				break
			done

			# Skip this line if we didn't find the "scope" element.
			[ $indx -ge 2 ] || continue

			loinfo=${lo[$indx]}
			loname=${loinfo%%:*}
			lonum=${loinfo##${loname}:}

			vipinfo=${lo[3]}
			vip=${vipinfo%%/*}
			[ -n "$lonum" ] || continue
		else
			# inet6
			vip=${lo[3]}
			vip=${vip%%/*}
			lonum=
		fi
                [ -n "$vip" ] || continue

		if [ ${Lo_indx[$vip]+_} ]; then
			Lo_num[$vip]="$lonum"
		else
			_Lo_init "discovered" "$vip" "$lonum"
		fi

		[ "${Lo_state_orig[$vip]}" != "init" ] || Lo_state_orig[$vip]="started"
		Lo_state[$vip]="started"
	done

	for ((i=0; i<${#Lo_ip[@]}; i++)) do
		vip=${Lo_ip[$i]}
		[ "${Lo_state[$vip]}" != "init" ] || Lo_state[$vip]="stopped"
		[ "${Lo_state_orig[$vip]}" != "init" ] || Lo_state_orig[$vip]="stopped"

		[ ${#vip} -le $IPMaxlenAll ] || IPMaxlenAll=${#vip}
		[ ${#vip} -le $NameMaxlenAll ] || NameMaxlenAll=${#vip}
		if [ "${Lo_losrc[$vip]}" == "configured" ]; then
			[ ${#vip} -le $IPMaxlenConf ] || IPMaxlenConf=${#vip}
			[ ${#vip} -le $NameMaxlenConf ] || NameMaxlenConf=${#vip}
		fi
	done

	return 0
}

function _Lo_reread_loopbacks
{
	GotLoopbacksAlready=0

	_Lo_get_loopbacks
	_Dsr_update_state
}

function _Lo_print_unconfigured
{
	typeset af i vip loout

	for ((i=0; i<${#Lo_ip[@]}; i++)) do
		vip=${Lo_ip[$i]}
		[ ${Lo_losrc[$vip]} != "configured" ] || continue

                # If the Dsr entry for this key exists, then it has already
                # been printed, either as a configured entry or as a
                # discovered entry.
		[ $(_Dsr_find_discovered_dsr_by_vip $vip) == "notfound" ] || continue

		if [ "${Lo_state[$vip]}" == "started" ]; then
			af=$(_addraf "$vip")
			[ "$af" == "4" ] || loout="lo"
			[ "$af" == "6" ] || loout="lo:${Lo_num[$vip]}"
		else
			loout="--"
		fi

		_emit_data "loopb" \
			   "${Lo_state[$vip]}" \
			   "$vip" \
			   "$vip" \
			   "--" \
			   "$loout" \
			   "--" \
			   "disc"
	done
}

function _Lo_dbg_print
{
	typeset af i vip losrc lonum state

	_Lo_get_loopbacks || return 1

	vprt2 "====== Loopbacks Start"
	vprt2 "======     Number of loopbacks = ${#Lo_ip[@]}"
	for ((i=0; i<${#Lo_ip[@]}; i++)) do
		vip=${Lo_ip[$i]}
		af=$(_addraf "$vip")
		losrc=${Lo_losrc[$vip]}
		lonum=${Lo_num[$vip]}
		state=${Lo_state[$vip]}
		if [ "$af" == "4" ]; then
			vprt2 "======         loopback$af: $losrc $state vip=$vip $lonum"
		else
			vprt2 "======         loopback$af: $losrc $state vip=$vip"
		fi
	done

	vprt2 "====== Loopbacks End"

	return 0
}

# =======================================================================
# End of Lo
# =======================================================================


# =======================================================================
# Iptables
# =======================================================================

function _Iptables_init
{
	typeset iptsrc="$1"
	typeset vip="$2"
	typeset dscp="$3"

	typeset dscp_dec indx key

	# Now we create a new Loopback.
	indx=${#Iptables_ip_dscp[@]}

	[ -z "$dscp" ] && dscp_dec= || dscp_dec=$(cvt2dec "$dscp")
	key=$(makekey "$vip" "$dscp_dec")

	Iptables_ip_dscp[$indx]="$key"
	Iptables_indx[$key]="$indx"
	Iptables_dscp[$key]="$dscp"
	Iptables_state[$key]="init"
	Iptables_state_orig[$key]="init"
	Iptables_iptsrc[$key]="$iptsrc"


	return 0
}

#
# Get iptables/ip6tables information given the address family (4/6).
#
# For now, we only look at the mangle table.  Other rules that might
# be running from other tables are ignored.
#
function _Iptables_get_iptables_af
{
	typeset af="$1"

	typeset dscp dscp_dec dscp_conf_dec dscp_field dscp_val dscp_val_field
	typeset vip vip_field iptablesout iptbl key line lines match_field pgm str

	[ "$af" == "6" ] || pgm="iptables"
	[ "$af" == "4" ] || pgm="ip6tables"

	# $? is the return value of the rightmost cmd that fails or zero otherwise.
	# This is usually the egrep.
	iptablesout=$(run $pgm -L -t mangle -n 2>&1 | run egrep DADDR | run sort)
	[ $? -lt 2 ] || return 1

	OIFS="$IFS"
	IFS=$'\n' lines=( $(echo "$iptablesout") )
	IFS="$OIFS"

	# Expecting output like this from the iptables cmd.
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x1cDADDR set 188.125.67.68
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x11DADDR set 188.125.82.253
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x13DADDR set 188.125.82.38
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x2bDADDR set 188.125.82.196
	#
	# On RHEL5, it's slightly different.
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x1c DADDR set 188.125.67.68
	#
	# Expecting output like this from the ip6tables cmd.
	# Sadly, it's a bit different from the iptables cmd.
	#  DADDR      all      anywhere    anywhere    DSCP match 0x24DADDR set 2001:4998:c:a06::2:4002
	#  DADDR      all      anywhere    anywhere    DSCP match 0x16DADDR set 2001:4998:c:a06::2:4003
	#  DADDR      all      anywhere    anywhere    DSCP match 0x18DADDR set 2001:4998:c:a06::2:4004
	#
	# On Rhel5, it's slightly different.
	#  DADDR      all      anywhere    anywhere    DSCP match 0x18 DADDR set 2001:4998:c:a06::2:4004

	if [ "$af" == "4" ]; then
		dscp_field=5
		match_field=6
		dscp_val_field=7
		vip_field=9
	else
		dscp_field=4
		match_field=5
		dscp_val_field=6
		vip_field=8
	fi

	for line in "${lines[@]}"; do
		iptbl=($line)

		[ "${iptbl[0]}" == "DADDR" ] || continue
		[ "${iptbl[$dscp_field]}" == "DSCP" ] || continue
		[ "${iptbl[$match_field]}" == "match" ] || continue

		dscp_val=${iptbl[$dscp_val_field]}
		dscp=${dscp_val%%DADDR}
		if [ "$dscp" == "$dscp_val" ]; then
			[ "$af" == "6" ] || vip_field=10
			[ "$af" == "4" ] || vip_field=9
		fi
		[ -z "$dscp" ] && dscp_dec= || dscp_dec=$(cvt2dec "$dscp")
		vip=${iptbl[$vip_field]}

		[ -n "$dscp" ] || continue
		[ -n "$vip" ] || continue

		key=$(makekey "$vip" "$dscp_dec")
		[ ${Iptables_indx[$key]+_} ] || \
			_Iptables_init "discovered" "$vip" "$dscp"

		conf_dscp_dec=$(cvt2dec ${Iptables_dscp[$key]})
		if [ $conf_dscp_dec -ne $dscp_dec ]; then
			str="Configured DSCP value "
			str+="(vip=$vip, dscp=${Iptables_dscp[$key]}) "
			str+="does not match started DSCP value "
			str+="(vip=$vip, dscp=$dscp)."
			echo "$str"
			continue;
		fi

		[ "${Iptables_state_orig[$key]}" != "init" ] || Iptables_state_orig[$key]="started"
		Iptables_state[$key]="started"
	done

	for ((i=0; i<${#Iptables_ip_dscp[@]}; i++)) do
		vip=${Iptables_ip_dscp[$i]%%,*}
		dscp=${Iptables_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		[ "${Iptables_state[$key]}" != "init" ] || Iptables_state[$key]="stopped"
		[ "${Iptables_state_orig[$key]}" != "init" ] || Iptables_state_orig[$key]="stopped"

		[ ${#vip} -le $IPMaxlenAll ] || IPMaxlenAll=${#vip}
		[ ${#vip} -le $NameMaxlenAll ] || NameMaxlenAll=${#vip}
		if [ "${Iptables_iptsrc[$key]}" == "configured" ]; then
			[ ${#vip} -le $IPMaxlenConf ] || IPMaxlenConf=${#vip}
			[ ${#vip} -le $NameMaxlenConf ] || NameMaxlenConf=${#vip}
		fi
	done
}

function _Iptables_get_iptables
{
	[ $GotIptablesAlready -eq 0 ] || return 0

	GotIptablesAlready=1

	_Iptables_get_iptables_af "4"
	_Iptables_get_iptables_af "6"

	return 0
}

function _Iptables_reread_iptables
{
	GotIptablesAlready=0

	_Iptables_get_iptables
	_Dsr_update_state
}

#
# Start an iptables/ip6tables rule.
#
# Returns
#   0 if the iptables rules was successfully started
#   1 otherwise
#
function _Iptables_start
{
	typeset vip="$1"
	typeset dscp="$2"

	typeset af key pgm rv

	key=$(makekey "$vip" "$dscp")
	[ "${Iptables_state[$key]}" == "stopped" ] || return 0

	af=$(_addraf "$vip")
	[ "$af" == "6" ] || pgm="iptables"
	[ "$af" == "4" ] || pgm="ip6tables"

	Iptables_state[$key]="starting"
	if run $pgm -t mangle -A PREROUTING -m dscp --dscp $dscp -j DADDR --set-daddr=$vip
	then
		Iptables_state[$key]="started"
		rv=0
	else

		Iptables_state[$key]="error"
		echo "Failed to start iptables rule for $vip=${Iptables_dscp[$key]}."
		rv=1
	fi

	return $rv
}

#
# Stop an iptables/ip6tables rule.
#
# Returns
#   0 if the iptables rules was successfully stopped
#   1 otherwise
#
function _Iptables_stop
{
	typeset vip="$1"
	typeset dscp="$2"

	typeset af key pgm rv

	key=$(makekey "$vip" "$dscp")
	[ "${Iptables_state[$key]}" == "started" ] || return 0

	[ -n "$dscp" ] || return 0

	Iptables_state[$key]="stopping"

	af=$(_addraf "$vip")
	[ "$af" == "6" ] || pgm="iptables"
	[ "$af" == "4" ] || pgm="ip6tables"

	if run $pgm -t mangle -D PREROUTING -m dscp --dscp $dscp -j DADDR --set-daddr=$vip
	then
		Iptables_state[$key]="stopped"
		rv=0
	else
		Iptables_state[$key]="error"
		rv=1
	fi

	return $rv
}

function _Iptables_restore_orig_state
{
	typeset vip="$1"
	typeset dscp="$2"

	typeset key

	key=$(makekey "$vip" "$dscp")
	if [ "${Iptables_state_orig[$key]}" == "stopped" ]; then
		[ "${Iptables_state[$key]}" != "started" ] || _Iptables_stop "$vip" "$dscp"
	fi
	if [ "${Iptables_state_orig[$key]}" == "started" ]; then
		[ "${Iptables_state[$key]}" != "stopped" ] || _Iptables_start "$vip" "$dscp"
	fi
}

function _Iptables_print_unconfigured
{
	typeset dscp i vip iptout key

	for ((i=0; i<${#Iptables_ip_dscp[@]}; i++)) do
		vip=${Iptables_ip_dscp[$i]%%,*}
		dscp=${Iptables_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		[ ${Iptables_iptsrc[$key]} != "configured" ] || continue

                # If the Dsr entry for this key exists, then it has already
                # been printed, either as a configured entry or as a
                # discovered entry.
		[ ! ${Dsr_dsrsrc[$key]+_} ] || continue

		[ "${Iptables_state[$key]}" == "started" ] || iptout="--"
		[ "${Iptables_state[$key]}" != "started" ] || iptout="up"

		_emit_data "iptbl" \
			   "${Iptables_state[$key]}" \
			   "$vip" \
			   "$vip" \
			   "${Iptables_dscp[$key]}" \
			   "--" \
			   "$iptout" \
			   "disc"
	done
}

function _Iptables_dbg_print
{
	typeset af dscp i vip iptsrc key state

	_Iptables_get_iptables
	[ $? -eq 0 ] || return 1

	vprt2 "====== Iptables Start"
	vprt2 "======     Number of iptables rules = ${#Iptables_ip_dscp[@]}"
	for ((i=0; i<${#Iptables_ip_dscp[@]}; i++)) do
		vip=${Iptables_ip_dscp[$i]%%,*}
		dscp=${Iptables_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		af=$(_addraf "$vip")
		iptsrc=${Iptables_iptsrc[$key]}
		state=${Iptables_state[$key]}
		vprt2 "======         iptables${af}: $iptsrc $state vip=$vip dscp=${Iptables_dscp[$key]}"
	done

	vprt2 "====== Iptables End"

	return 0
}

# =======================================================================
# End of Iptables
# =======================================================================

# Global initialization.
function _init
{
	typeset rv=0 norun_save

	norun_save=$NoRun
	NoRun=no

	_Dsr_read_configuration || { rv=1 && [ $NoFail -eq 1 ]; } || { NoRun=$norun_save; return 1; }

	_Dsr_dbg_print || true

	_Lo_get_loopbacks || { rv=1 && [ $NoFail -eq 1 ]; } || { NoRun=$norun_save; return 1; }

	_Lo_dbg_print

	_Iptables_get_iptables || { rv=1 && [ $NoFail -eq 1 ]; } || { NoRun=$norun_save; return 1; }

	_Iptables_dbg_print

	_Dsr_init_discovered_dsrs

	_Dsr_update_state

	_Cache_read_file
	_Cache_dbg_print

	NoRun=$norun_save

	return $rv
}

# Check DSR status.
function status
{
	typeset dscp i key vip rv=0

	# Continue on through all of the status even if some parts
	# of it fail.  Get everything we can.
	NoFail=1

	_init || rv=$?

	# Check all of the DSRs.
	[ $(_Dsr_configured_dsr_count) -gt 0 ] || [ $AllOpt -ne 0 ] ||
		{ echo "No configured DSRs found."; return 0; }

	[ ${#Lo_ip[@]} -gt 0 ] || [ ${#Iptables_ip_dscp[@]} -gt 0 ] ||
		{ echo "No loopback aliases or iptables rules found."; return 0; }

	[ "$NoHeader" == "yes" ] || _Dsr_print_dsr_header

	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")
		[ $AllOpt -eq 1 ] || [ ${Dsr_dsrsrc[$key]} == "configured" ] || continue
		_Dsr_print_one_dsr "$i" || rv=1
	done

	[ $AllOpt -eq 0 ] || _Lo_print_unconfigured
	[ $AllOpt -eq 0 ] || _Iptables_print_unconfigured

	return $rv
}

# Display a one line DSR status.
function check
{
	typeset dscp i vip key num_started=0 rv=0

	# Continue on through all of the status even if some parts
	# of it fail.  Get everything we can.
	NoFail=1

	_init >/dev/null 2>&1 ||
		{ rv=$?; echo "DSR configuration error discovered."; return $rv; }

	# Check all of the DSRs.
	[ $(_Dsr_configured_dsr_count) -gt 0 ] ||
		{ echo "No configured DSRs found."; return 3; }

	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		# Skip DSRs that weren't read from the config files.
		[ ${Dsr_dsrsrc[$key]} == "configured" ] || continue

		[ ${Dsr_state[$key]} != "started" ] || (( num_started++ )) || true
	done

	if [ $num_started == 0 ]; then
		echo "No DSRs started."
		rv=1
	elif [ $num_started == ${#Dsr_ip_dscp[@]} ]; then
		echo "All DSRs started."
	else
		echo "Some DSRs not started."
		rv=3
	fi

	return $rv
}

#
# Start all configured DSRs.
#
# If there are conflicts in the conf files, then nothing gets started.
#
# If there are failures while starting the DSRs, then we return to the state
# of the DSRs when we started.  If we started a DSR, then it is stopped.  DSRs
# that are not configured are left unchanged.  iptables rules and loopbacks
# that are set but are not configured are also left unchanged.
#
# Returns
#   0 if all configured DSRs are successfully started
#   1 otherwise
#
function startdsrs
{
	typeset dscp i vip key rv=0

	_init || return 1

	# Start all of the configured DSRs.
	for ((i=0; i<${#Dsr_ip_dscp[@]}; i++)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		# Skip DSRs that weren't read from the config files.
		[ ${Dsr_dsrsrc[$key]} == "configured" ] || continue

		vprt2 "====== Starting DSR $vip=$dscp"

		[ "${Dsr_state[$key]}" != "started" ] || continue

		Dsr_state[$key]="starting"

		! _Dsr_l3dsr "$vip" "$dscp" || \
		_Iptables_start "$vip" "$dscp" || \
			{ Dsr_state[$key]="error"; rv=1; break; }

		_Lo_start "$vip" || { Dsr_state[$key]="error"; rv=1; break; }

		Dsr_state[$key]="started"
	done

	[ $rv -eq 0 ] || _Dsr_restore_dsrs_to_orig_state

	return $rv
}

function stopdsrs
{
	typeset dscp i vip key

	# We try as hard as we can to stop the DSRs even if we have
	# some failures.
	No_Fail=1

	_init || true

	# Stop all of the DSRs in reverse order.
	for ((i=${#Dsr_ip_dscp[@]}-1; i>=0; i--)) do
		vip=${Dsr_ip_dscp[$i]%%,*}
		dscp=${Dsr_ip_dscp[$i]##*,}
		key=$(makekey "$vip" "$dscp")

		# Skip DSRs that weren't read from the config files.
		[ ${Dsr_dsrsrc[$key]} == "configured" ] || continue

		vprt2 "====== Stopping DSR $vip=${Dsr_dscp[$key]}"

		! _Dsr_l3dsr "$vip" "$dscp" || _Iptables_stop "$vip" "$dscp"
		_Lo_stop "$vip"
	done

	# If $AllOpt is set, then remove all the DSRs we can find.
	[ $AllOpt -eq 1 ] || return 0

	_Iptables_reread_iptables
	_Lo_reread_loopbacks

	for ((i=0; i<${#Iptables_ip_dscp[@]}; i++)) do
		vip=${Iptables_ip_dscp[$i]%%,*}
		dscp=${Iptables_ip_dscp[$i]##*,}
		vprt2 "====== Removing iptables rule $vip=$dscp"
		_Iptables_stop "$vip" "$dscp"
	done

	for ((i=0; i<${#Lo_ip[@]}; i++)) do
		vprt2 "====== Removing loopback alias ${Lo_ip[$i]}"
		_Lo_stop "${Lo_ip[$i]}"
	done

	return 0
}

#
# cleanup is called when the script is terminated prematurely. It cleans up
# whatever mess there is.
#
function cleanup
{
	_Dsr_restore_dsrs_to_orig_state

	exit 1
}

# Dup stdout to FD 3.
# This lets us do
#     run foo > /dev/null 2>&1
# The prints in run come out to stdout and the output from foo goes to /dev/null
exec 3>&1

#
# Parse options
#
AllOpt=0
ConfigDir=/etc/dsr.d
ConfigFile=
VerboseLevel=0
NoRun=no
NoFail=0
while getopts ad:f:hnvx OPTION
do
    case $OPTION in
	a)      AllOpt=1
		;;
	d)      ConfigDir="$OPTARG"
		;;
	f)      ConfigFile="$OPTARG"
		;;
	n)      NoRun=yes
		;;
	v)      (( ++VerboseLevel ))
		;;
	x)      NoHeader=yes
		;;
	h)      echo "$Usage"
		exit 0
		;;
	\?)     echo "$Usage" >&2
		exit 1
		;;
    esac
done

export VerboseLevel

# Shift away all option arguments.
shift `expr $OPTIND - 1`

[ $# -ge 1 ] || { echo "Missing action argument." >&2; exit 1; }

Action="$1"
shift

function traperr
{
        typeset lno="$1"

	echo Command \"$BASH_COMMAND\" failed at line $lno. Exiting.
	exit 1
}

# We set pipefail so that we can determine if anything in the entire pipeline
# failed.
set -o pipefail
#set -o errexit
#set -o errtrace
#trap 'traperr $LINENO' ERR

trap "cleanup" 1 2 3 9

case "$Action" in
  check)            check_root
		    check
		    retval=$?
		    ;;
  status)           check_root
		    status
		    retval=$?
		    ;;
  restart)          check_root
		    stopdsrs
		    startdsrs
		    ;;
  start)            check_root
		    startdsrs
		    ;;
  stop)             check_root
		    stopdsrs
		    ;;
  *)                echo "Invalid action provided ($Action)" >&2
		    echo "$Usage" >&2
		    retval=1
		    ;;
esac

exit $retval
