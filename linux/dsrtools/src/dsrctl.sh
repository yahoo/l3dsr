#!/bin/ksh

# dsrctl controls and provides status about L2DSR and L3DSR VIPs.
# The VIPs are configured in files contained in /etc/dsr.d.  VIPs
# can be started, stopped, and checked.  Status can be displayed
# for configured VIPs.
#
# Additional information can be found in the dsrctl(1) man page.

ScriptName=${0##*/}

DaddrTableFile=/sys/module/xt_DADDR/parameters/table
DfltTable=mangle
FakeAliasNum=0
GotLoopbacksAlready=0
GotConfAlready=0
GotIptablesAlready=0
IptablesChain=PREROUTING
Kmod=xt_DADDR
KmodLoaded=0
NoHeader=no
Ip6Disabled=-1

# We keep different maxlens for when we print with the -a option and when we
# just print the configured DSRs.
typeset -A Maxlen

# The iptables table varies among the software versions of the kernel module.
# Initially, it was hardcoded to be "mangle", and later gained the capability
# of letting the installer choose.  The table cannot be changed once the
# kernel module is loaded.  Some actions of this script require that the
# kernel module be loaded (e.g., start, stop), but some don't (status).
# Because of this, we need to keep the state of the table for use in this
# script.
#
# Table subfields
#     Name    Values
#     ====    ======
#     state   {detected, loaded, unloaded}
#     val     {mangle, raw}
#     print   {mangle, raw, --}
typeset -A Table

# Set up patterns that we use to match configuration lines.
IPv4Pat="+([\d]).+([\d]).+([\d]).+([\d])"
IPv6Pat="+([[:xdigit:]:])"
FqdnPat="+([[:alnum:].-])"
DscpPat="+([[:xdigit:]xX])"
SpPat="*([\s])"
CmtPat="$SpPat*(#*)"

L3dsrIPv4Pat=$SpPat$IPv4Pat$SpPat=$SpPat$DscpPat$CmtPat
L3dsrIPv6Pat=$SpPat$IPv6Pat$SpPat=$SpPat$DscpPat$CmtPat
L3dsrFqdnPat=$SpPat$FqdnPat$SpPat=$SpPat$DscpPat$CmtPat

L2dsrIPv4Pat=$SpPat$IPv4Pat$CmtPat
L2dsrIPv6Pat=$SpPat$IPv6Pat$CmtPat
L2dsrFqdnPat=$SpPat$FqdnPat$CmtPat

EmptyLinePat=$CmtPat

# All of the information about DSRs we start is kept in the Dsr associative
# array except the Dsr_keys indexed array which is used to keep the order of
# what we start.
#
# The Dsr and Iptables associative arrays are accessed by a key containing
# the normalized numeric VIP and the normalized DSCP values.  The
# makekey/makekey_normalized functions are always used to create the key from
# the VIP/DSCP values.  Dsr also contains elements that are keyed by the FQDN
# if used in the configuration file(s).
#
# The unmodified form of the VIP that is provided in the .conf file is stored
# in Dsr[$key].vipname.
# The unmodified form of the DSCP that is provided in the .conf file is stored
# in Dsr[$key].dscp.
#
# The Lo associative array is accessed only by the numeric normalized VIP.
#
# The following list shows all possible states.
# state (Dsr[$key].state, Lo[$key].state, Iptables[$key].state)
#     init
#     error
#     stopping
#     stopped
#     starting
#     started
#     partial
#
# These are all of the possible types that are supported.
# type
#     l2dsr
#     l3dsr
#     iptbl (for iptables rules not related to DSR)
#     loopb (for loopbacks not related to DSR)
#
# These are the sources where iptables rules and loopbacks are found.
# dsrsrc
#     configured
#     discovered

#
# JFYI: This is how we check for existence of an element in an array
#       (indexed or associative) in ksh/bash.
#           [[ ${arr[key]+_} ]]   || print -- "notfound"
#           [[ ! ${arr[key]+_} ]] || print -- "found"
#

typeset -a Dsr_keys			# indexed array of keys
typeset -A Dsr
# Dsr subfields
#     state				# current state of DSR
#     indx				# indx of this DSR
#     type				# type of DSR: l3dsr, l2dsr
#     vipname				# configured VIP (fqdn, if provided)
#     vipnumeric			# convert from .conf VIP to numeric VIP
#     dscp				# configured DSCP value
#     dsrsrc				# source of this DSR
#     config_file			# where this DSR was configured
#     config_file_lineno		# line number of this DSR in .conf file

typeset -a Lo_keys			# indexed array of keys
typeset -A Lo
# Lo subfields
#     state				# state of the loopback
#     state_orig			# original state of loopback
#     indx				# indx of this loopback
#     num				# loopback number
#     vipname				# unmodified VIP name of loopback
#     vipnumeric			# unmodified numeric VIP of loopback
#     losrc				# source of this loopback (configured, discovered)

typeset -a Iptables_keys		# indexed array of keys
typeset -A Iptables
# Iptables subfields
#     state				# state of the iptables rule
#     state_orig			# original state of the iptables rule
#     indx				# indx of the iptables rule
#     dscp				# unmodifie DSCP val of iptables rule
#     table				# iptables table
#     vipname				# unmodified VIP name of iptables rule
#     vipnumeric			# unmodified numeric VIP of loopback
#     iptsrc				# source of this iptables rule (configured, discovered)
#     rulecnt				# number of identical iptables rules for this VIP


#
# Add the requested newpath to the given path variable.
#
function addpath
{
	nameref path=$1
	typeset newpath=$2

	[[ -d $newpath ]] || return

	# If newpath already exists in the path variable, then just return.
	[[ :$path: != *(?):$newpath:*(?) ]] || return

	path="${path:+$path:}$newpath"
}

#
# Return a reasonable path for this script to be able to run.
#
# Note that initpath ignores the PATH variable provided in the environment for
# this script when creating the PATH.
#
function initpath
{
	typeset path

	path=$(/usr/bin/getconf PATH 2>/dev/null || print /usr/bin)
	[[ -n $path ]] || path=/usr/bin

	addpath path /usr/sbin
	addpath path /sbin

	print "$path"
}

# Initialize the PATH to the set of directories needed by this script.
#
# initpath ignores the existing PATH variable.
#
# PATH must be set before we try to execute any programs in the PATH.
export PATH=$(initpath)

Usage=$(cat <<EOF
Usage: $ScriptName [-d <configdir>] [-f <configfile>] [-ahnvx] <action>
       -a       For status, print status for all discovered loopbacks
                and iptables rules, not just configured DSRs.
       -d dir   Specify DSR config directory.  Defaults to /etc/dsr.d.
       -f file  Read a single DSR config from this file.
                The -d option is ignored if -f is used.
       -h       Print a usage statement and exit.
       -i       Insert rules at the top of the iptables chain instead
                of appending.  The default is to append the rules.
       -k       Keep the xt_DADDR module loaded when stopping DSRs.
                The xt_DADDR module is removed by default when running
                the stop action.
       -n       Don't actually perform the operations.  This option
                is useful with the verbose option.
       -s v:v   Set the sleep values for removing the xt_DADDR module.
                The first value is the number of seconds to wait before
                attempting the first modprobe.  The second value is
                the number of seconds to wait before all subsequent
                attempts to remove the module.  Floating point values
                are allowed.
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
#     VerboseLevel==0: don't print the cmd
#     VerboseLevel==1: print the cmd
#     VerboseLevel>=2: print the curdate and cmd
# The first arg is always the verboselevel limit.
# If $VerboseLevel < $vlevel, then the remaining arguments are not printed.
function vprt
{
	typeset vlevel
	typeset curdate=

	vlevel=$1
	shift

	(( VerboseLevel >= vlevel )) || return 0
	(( VerboseLevel < 2 )) || curdate="$(date +%Y%m%d-%H:%M:%S): "
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
	[[ $NoRun == yes ]] || "$@" || rv=$?
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
	# We default the verbose level to 1 for printing commands.
	vrun1 "$@"
}

# This function exits if the caller is not root.
function check_root
{
	if (( $(id -u) != 0 )); then
		print -u2 -- "You must be root to run this command."
		exit 1
	fi
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

        # If we have already determined if IPv6 is disabled, just return the
        # saved result.
	(( Ip6Disabled < 0 )) || return $Ip6Disabled

	# Both files must exist or IPv6 is disabled.
	[[ -e $sysmodfile ]] && [[ -e $procfile ]] || { Ip6Disabled=0; return 0; }

	# If both file values are 0, IPv6 is enabled.
	(( $(<$sysmodfile) )) || (( $(<$procfile) )) || { Ip6Disabled=1; return 1; }

	Ip6Disabled=0
	return 0
}

#
# The given IP address is a FQDN.  Convert it to an IPv4 dotted decimal
# address and return it.  If the name can't be converted, then return
# "notfound".
#
function fqdn_to_ipv4_addr
{
	typeset fqdn=$1

	typeset ipaddrs line numericip oifs
	typeset -a lines

	ipaddrs=$(run getent ahostsv4 "$fqdn") || return 1

	oifs=$IFS
	IFS=$'\n'
	lines=( $(print -- "$ipaddrs") )
	IFS=$oifs

	for line in "${lines[@]}"; do
		[[ $line != *STREAM* ]] || continue
		numericip=${line%% *}
		[[ $numericip != $IPv4Pat ]] || { print -- "$numericip"; return 0; }
	done

	print -- "notfound"

	return 0
}

# Returns
#   0 if the given address is an IPv4 address
#   1 if the given address is an IPv6 address
function ipv4addr
{
	[[ $1 != *:* ]] && return 0 || return 1
}

# Returns the address family (4/6) based on IP address.
# Defaults to IPv4.
function addraf
{
	typeset vip=$1

	typeset af=4

	ipv4addr "$vip" || af=6

	print -- "$af"
}

# Create a key from the given VIP and DSCP.
# No normalization occurs in this function -- the VIP and DSCP
# must already be normalized.
function makekey
{
	typeset normvip=$1
	typeset normdscp=$2

	print -- "$normvip,$normdscp"
}

# Extract the key, normvip, and normdscp from the given value.
function extractkey
{
	typeset val=$1
	nameref key=$2
	nameref normvip=$3
	nameref normdscp=$4

	key=$val
	normvip=${val%%,*}
	normdscp=${val##*,}
}

# Given the VIP and DSCP, normalize them and then convert them into a key used
# for the appropriate associative arrays (Dsr[$key].*, Iptables[$key].*).
function makekey_normalized
{
	typeset vip=$1
	typeset dscp=$2

	typeset normdscp normvip

	normvip=$(normalize_vip "$vip")
	normdscp=$(normalize_dscp "$dscp")

	makekey "$normvip" "$normdscp"
}

# Normalize the DSCP value.
# If the DSCP is empty (L2DSR), then the empty string is returned.
# Otherwise, the value is converted to decimal.
function normalize_dscp
{
	typeset dscp=$1

	[[ -n $dscp ]] || { print -- "$dscp"; return; }

	print -- $(( $dscp ))
}

# Normalize an IPv6 address.
#
# The same IPv6 address, in some cases, can be written in different ways.
#     Upper and lower case letters are allowed.
#     Groups of 0s can be written with "::", but the "::" can be located in
#         more than one place if there is more than one group of 0s.
#     The 4 byte addresses are allowed leading zeroes.
# normalize_ipv6 takes an IPv6 address and produces an unambiguous representation
# of that address.  The format of the normalized IPv6 address has these
# characteristics.
#     Only lower case hex letters are used.
#     Each group of hex digits is prefixed with sufficient 0s to create a 4
#         character hex value
#     Each group of hex digits is separated with a colon.
#     The resulting normalized IPv6 address is a legal representation of the
#         address.
#
# Note that the normalized address is only ever used internally -- it is
# never printed except through debugging statements.
function normalize_ipv6
{
	typeset ip=$1

	typeset -a ipv6
	typeset -a afterarr
	typeset -a zero=(0 0 0 0 0 0 0 0)
	typeset after before nzeroes

	# Split the address into before and after strings.
	# The before and after strings can be empty.
	before=${ip%%::*}
	after=${ip##$before::}

	# If there's no ::, then before and after are the same.  There's no
	# point in having both be the same, so we arbitrarily clear out the
	# after string.
	[[ $before != $after ]] || after=

	# Split the before/after strings into arrays.
	oifs=$IFS
	IFS=:
	ipv6=( $before )
	afterarr=( $after )
	IFS=$oifs

	# Clear out the :: zeroes.
	nzeroes=$(( 8 - ${#ipv6[@]} - ${#afterarr[@]} ))
	(( nzeroes >= 0 )) || nzeroes=0
	ipv6+=( ${zero[@]:0:$nzeroes} )

	# Add the components after the ::.
	ipv6+=( ${afterarr[@]} )

	printf "%04x:%04x:%04x:%04x:%04x:%04x:%04x:%04x\n" \
		0x${ipv6[0]} 0x${ipv6[1]} 0x${ipv6[2]} 0x${ipv6[3]} \
		0x${ipv6[4]} 0x${ipv6[5]} 0x${ipv6[6]} 0x${ipv6[7]}
}

# Normalize the given IP address so that comparisons we
# make later on are not different based on upper/lower case
# and leading zero choices.
#
# normalize_vip accepts IPv4 and IPv6 addresses as well as FQDNs.
function normalize_vip
{
	typeset vip=$1

	# Determine what kind of IP address it is: IPv4, IPv6, FQDN.
	# For IPv4 and FQDN, just return what we were given.
	[[ $vip != $IPv4Pat ]] || { print -- "$vip"; return; }
	[[ $vip != $IPv6Pat ]] || { normalize_ipv6 "$vip"; return; }
	print -- "$vip"
}

# Check whether the argument is numeric.  We accept decimal,
# octal, and hex values.  No fractions are accepted and neither
# are plus/minus.
# This function works back to ksh93.
function isnumeric
{
	case $1 in
	  0)			return 0;;	# decimal
	  +([1-9])*([\d]))	return 0;;	# decimal
	  0[xX]+([[:xdigit:]]))	return 0;;	# hex
	  0+([0-7]))		return 0;;	# octal
	esac

	return 1
}

# Check whether the argument is a decimal fraction.  The following values are
# examples of what is accepted.
#     0
#     123
#     .23
#     0.23
#     123.23
function is_dec_fraction
{
	case $1 in
	  0)                        return 0;;  # decimal
	  +([1-9])*([\d]))          return 0;;  # decimal
	  \.+([\d]))                return 0;;  # decimal fraction
	  0\.+([\d]))               return 0;;  # decimal fraction
	  +([1-9])*([\d])\.+([\d])) return 0;;  # decimal fraction
	esac

	return 1
}

# Emit a single line of output based on the provided arguments
# and appropriate configuration values.
function emit_data
{
	typeset dsrtype=$1
	typeset state=$2
	typeset name=$3
	typeset vipnumeric=$4
	typeset dscp=$5
	typeset loopback=$6
	typeset iptables=$7
	typeset table=$8
	typeset src=$9

	typeset ipmaxlen namemaxlen

	if (( AllOpt == 0 )); then
		namemaxlen=${Maxlen[nameconf]}
		ipmaxlen=${Maxlen[ipconf]}
		tblnamemaxlen=${Maxlen[tblnameconf]}
	else
		namemaxlen=${Maxlen[nameall]}
		ipmaxlen=${Maxlen[ipall]}
		tblnamemaxlen=${Maxlen[tblnameall]}
	fi

	[[ $dsrtype    != = ]] || dsrtype=$(Dsr_header_sep 5)
	[[ $state      != = ]] || state=$(Dsr_header_sep 7)
	[[ $name       != = ]] || name=$(Dsr_header_sep $namemaxlen)
	[[ $vipnumeric != = ]] || vipnumeric=$(Dsr_header_sep $ipmaxlen)
	[[ $dscp       != = ]] || dscp=$(Dsr_header_sep 4)
	[[ $loopback   != = ]] || loopback=$(Dsr_header_sep 8)
	[[ $iptables   != = ]] || iptables=$(Dsr_header_sep 8)
	[[ $table      != = ]] || table=$(Dsr_header_sep $tblnamemaxlen)
	[[ $src        != = ]] || src=$(Dsr_header_sep 4)

	if (( AllOpt == 0 )); then
		printf "%-5s %-7s %-${namemaxlen}s  %-${ipmaxlen}s  %-4s %-8s %s\n" \
			"$dsrtype" \
			"$state" \
			"$name" \
			"$vipnumeric" \
			"$dscp" \
			"$loopback" \
			"$iptables"
	else
		printf "%-5s %-7s %-${namemaxlen}s  %-${ipmaxlen}s  %-4s %-8s %-8s %-${tblnamemaxlen}s %s\n" \
			"$dsrtype" \
			"$state" \
			"$name" \
			"$vipnumeric" \
			"$dscp" \
			"$loopback" \
			"$iptables" \
			"$table" \
			"$src"
	fi
}

# =======================================================================
# Dsr
# =======================================================================

#
# Determine what kind of IP address we have and then initialize the given DSR
# entry.  The Dsr[$key].* data structures remain unchanged if the new DSR
# conflicts or is otherwise invalid.
#
# Returns
#     0 success
#     1 failure

function Dsr_init
{
	typeset dsrsrc=$1
	typeset vip=$2
	typeset dscp=$3
	typeset config_file=$4
	typeset lineno=$5

	typeset fqdn indx key key2 normdscp vipnumeric

	# We accept both FQDNs and numeric IPs.
	#
	# If we get a FQDN, then it is used, by historical convention, only
	# for the IPv4 address even if an IPv6 address exists for the FQDN.
	#
	# You can still have an IPv6 address, but it must be given as an IPv6
	# address, not as a name.
	if [[ $vip == $IPv4Pat ]]; then
		vipnumeric=$vip
		fqdn=$vip
	elif [[ $vip == $IPv6Pat ]]; then
		vipnumeric=$vip
		fqdn=$vipnumeric
	else
		# FQDN
		vipnumeric=$(fqdn_to_ipv4_addr "$vip" 2>&1)
		if (( $? != 0 )) || [[ $vipnumeric == notfound ]]; then
			print -- "Cannot convert fqdn \"$vip\" to an IPv4 address."
			return 1
		fi

		fqdn=$vip
	fi

	# Determine if this DSR is valid, duplicate, etc.
	Dsr_validate_dsr "$fqdn" "$vipnumeric" "$dscp" "$config_file" "$lineno" || \
		{ (( $? == 1 )) && return 0 || return $?; }

	# Now we create a new Dsr.
	indx=${#Dsr_keys[@]}

	update_maxlen ipconf   ${#vipnumeric}
	update_maxlen ipall    ${#vipnumeric}
	update_maxlen nameconf ${#fqdn}
	update_maxlen nameall  ${#fqdn}

	# Create the key for this DSR.
	key=$(makekey_normalized "$vipnumeric" "$dscp")

	Dsr_keys[$indx]=$key
	Dsr[$key].indx=$indx
	Dsr[$key].state=init
	Dsr[$key].dscp=$dscp
	Dsr[$key].dsrsrc=$dsrsrc
	Dsr[$key].vipname=$fqdn
	Dsr[$key].vipnumeric=$vipnumeric

	# It is sometimes more convenient to look up a DSR using its FQDN, so
	# we allow a second key to be created that combines the FQDN and the
	# normalized DSCP.  Without this, we would need to convert the FQDN
	# to its IP address multiple times.  It's faster to do the conversion
	# once and provide a lookup.
	normdscp=$(normalize_dscp "$dscp")
	key2=$(makekey "$fqdn" "$normdscp")
	[[ ${Dsr[$key2].vipnumeric+_} ]] || Dsr[$key2].vipnumeric=$vipnumeric

	[[ -n $dscp ]] && \
		Dsr[$key].type=l3dsr || \
		Dsr[$key].type=l2dsr

	Dsr[$key].config_file=$config_file
	Dsr[$key].config_file_lineno=$lineno

	return 0
}

# Validate the config input line.
#
# The purpose of this function is to look at the line and verify that it could
# be a valid configuration line, at least lexically.  We're not performing
# exhaustive/semantic validation.  We'd just like to let the caller know that,
# for example, using /etc/passwd as an input is not useful.
#
# Returns
#     0   Valid, but does not contain VIP.
#     1   Valid and contains proper VIP.
#     2   Not a valid VIP line.
#
# If the line is invalid, the reason is printed.
# If the line is valid, but contains no VIP, then an empty line is printed.
#     These are empty and comment lines.
# If the line is valid, and contains a VIP, then the line is printed without
#     spaces and comments.
function Dsr_validate_conf_line
{
	typeset line=$1

	typeset newline

	# Check for empty lines and lines that only contain comments.
	if [[ $line == $EmptyLinePat ]]; then
		newline=
		vprt3 "====== Lexical analysis recognizes empty/comment line ($line)"
		print  -- "$newline"
		return 0
	fi

	# Check for L3DSR IPv4 numeric address
	if [[ $line == $L3dsrIPv4Pat ]]; then
		newline=${.sh.match[2]}.${.sh.match[3]}.${.sh.match[4]}.${.sh.match[5]}=${.sh.match[8]}
		vprt3 "====== Lexical analysis recognizes L3DSR IPv4 ($newline)"
		print -- "$newline"
		return 1
	fi

	# Check for L3DSR IPv6 address
	if [[ $line == $L3dsrIPv6Pat ]]; then
		newline=${.sh.match[2]}=${.sh.match[5]}
		vprt3 "====== Lexical analysis recognizes L3DSR IPv6 ($newline)"
		print -- "$newline"
		return 1
	fi

	# Check for L3DSR FQDN
	#     This regex allows IPv4 addresses such as:
	#         124.40.n50.34
	#     Lexically, they are correct and not caught here.
	if [[ $line == $L3dsrFqdnPat ]]; then
		newline=${.sh.match[2]}=${.sh.match[5]}
		vprt3 "====== Lexical analysis recognizes L3DSR FQDN ($newline)"
		print -- "$newline"
		return 1
	fi

	# Check for L2DSR IPv4 numeric address
	if [[ $line == $L2dsrIPv4Pat ]]; then
		newline=${.sh.match[2]}.${.sh.match[3]}.${.sh.match[4]}.${.sh.match[5]}
		vprt3 "====== Lexical analysis recognizes L2DSR IPv4 ($newline)"
		print -- "$newline"
		return 1
	fi

	# Check for L2DSR IPv6 address
	if [[ $line == $L2dsrIPv6Pat ]]; then
		newline=${.sh.match[2]}
		vprt3 "====== Lexical analysis recognizes L2DSR IPv6 ($newline)"
		print -- "$newline"
		return 1
	fi

	# Check for L2DSR FQDN
	if [[ $line == $L2dsrFqdnPat ]]; then
		newline=${.sh.match[2]}
		vprt3 "====== Lexical analysis recognizes L2DSR FQDN ($newline)"
		print -- "$newline"
		return 1
	fi

	print -- "Unrecognized VIP/DSCP."
	return 2
}

#
# Dsr_process_conf_line processes a single line from the config file.
#
# The given line is validated and if found to be a valid VIP line, the
# appropriate array entries are created (Dsr, Lo, Iptables).
#
# Returns
#     0   Valid line (empty/comment/VIP).
#             If a VIP line was found, then it was valid and properly inserted
#             into the data arrays (Dsr, Lo, Iptables).
#     1   Not a valid VIP line.
#
function Dsr_process_conf_line
{
	typeset line=$1
	typeset lineno=$2
	typeset config_file=$3

	typeset dscp key linevalid name rv=0
	typeset validaterv validline vip vipnumeric

	validline=$(Dsr_validate_conf_line "$line")
	validaterv=$?

	# These are lines that are empty or only contain comments.
	(( validaterv != 0 )) || return 0;

	if (( validaterv == 2 )); then
		# These are invalid lines.
		print -u2 -- "Invalid config line at $config_file, line $lineno.  $validline"
		print -u2 -- "Aborting."
		exit 1
	fi

	# Use validline here since it's preprocessed to an easier-to-handle form
	case $validline in
	  Version*)
		# This is the Version line.
		name=${validline%%=*}
		Version=${validline##$name=}
		;;
	  *)
		# Split the line into VIP and DSCP.
		vip=${validline%%=*}
		dscp=
		[[ $validline != *=* ]] || dscp=${validline##$vip=}

		# Initialize the DSR.
		Dsr_init "configured" "$vip" "$dscp" "$config_file" "$lineno" || \
			return 1

		# The key created here by makekey takes a VIP that is
		# one of these.
		#     FQDN, if that's what was provided
		#     Otherwise, the provided numeric VIP
		#
		# The Dsr_init above created associative array elements for
		# both types of keys.
		key=$(makekey_normalized "$vip" "$dscp")
		vipnumeric=${Dsr[$key].vipnumeric}

		Lo_init configured "$vipnumeric" "$vip" "" || rv=1

		[[ -z $dscp ]] || \
			Iptables_init configured \
				       "$vipnumeric" \
				       "$vip" \
				       "$dscp" || rv=1

		;;
	esac

	return $rv
}

#
# Read the dsr configuration file.
#
function Dsr_read_config_file
{
	typeset config_file=$1

	typeset line lineno rv=0

	lineno=0
	while IFS= read -r line; do
		(( lineno++ ))
		Dsr_process_conf_line "$line" "$lineno" "$config_file" || rv=1
	done < $config_file

	# If there is anything left in $line, then the last line didn't
	# have a terminating newline.  Process the last line here.
	if [[ -n $line ]]; then
		(( lineno++ ))
		Dsr_process_conf_line "$line" "$lineno" "$config_file" || rv=1
	fi

	return $rv
}

#
# Read the configuration file.
# Look first for $ConfigFile.  It it's provided, then only work with that file.
# If there is no $ConfigFile, then look in $ConfigDir and load all of the
# *.conf files there.
#
function Dsr_read_configuration
{
	typeset f oifs rv=0 v
	typeset -a files

	(( GotConfAlready == 0 )) || return 0

	GotConfAlready=1

	if [[ -n $ConfigFile ]]; then
		[[ -r "$ConfigFile" ]] || \
			{ print -u2 -- "Cannot read the configuration file ($ConfigFile)."; return 1; }

		vprt2 "===== Loading config file $ConfigFile"
		Dsr_read_config_file "$ConfigFile" || return 1
	else
		if [[ ! -d "$ConfigDir" ]]; then
			print -u2 -- "Cannot find the configuration directory ($ConfigDir).  " \
				     "Is dsrtools installed?"
			return 0
		fi

		oifs=$IFS
		IFS=$'\n'
		files=( $(run find -L "$ConfigDir" -type f -name \*.conf | run sort) )
		rv=$?
		IFS=$oifs
		(( rv == 0 )) || \
			{ print -u2 -- "Cannot get file list from \"$ConfigDir\"."; return 1; }

		for f in "${files[@]}"; do
			vprt2 "===== Loading config file ($f)"
			Dsr_read_config_file "$f" || return 1
		done
	fi

	return 0
}

# Create a header separator ('=') with given width.
function Dsr_header_sep
{
	printf '=%.0s' {1..$1}
}

# Print the header.
function Dsr_print_dsr_header
{
	typeset ipaddr=ipaddr
	typeset name=name
	typeset iptbl=iptbl

	# Set the max column header length in case the header is longer than
	# the items themselves.  For example, "iptbl" is longer than "raw".
	update_maxlen ipall       ${#ipaddr}
	update_maxlen nameall     ${#name}
	update_maxlen tblnameall  ${#iptbl}

	update_maxlen ipconf      ${#ipaddr}
	update_maxlen nameconf    ${#name}
	update_maxlen tblnameconf ${#iptbl}

	emit_data type state $name $ipaddr dscp loopback iptables $iptbl src
	emit_data =    =     =     =       =    =        =        =      =
}

# Calculate the state of a DSR based on the state of the loopbacks and
# iptables rules.
# A DSR can be in these states.
#     stopped
#     partial
#     started
#     error
function Dsr_calculate_state
{
	typeset normvip=$1
	typeset normdscp=$2

	typeset key startedcnt=0 state

	key=$(makekey "$normvip" "$normdscp")
	if Dsr_l3dsr "$normvip" "$normdscp"; then
		[[ ${Lo[$normvip].state} != started ]] || \
			(( startedcnt++ )) || :
		[[ ${Iptables[$key].state} != started ]] || \
			(( startedcnt++ )) || :

		case $startedcnt in
		  0)   state=stopped;;
		  1)   state=partial;;
		  2)   state=started;;
		  *)   state=error;;
		esac
	else
		state=stopped
		[[ ${Lo[$normvip].state} != started ]] || state=started
		[[ ! ${Iptables[$key].state+_} ]] || \
			[[ ${Iptables[$key].state} != started ]] || \
			state=error
	fi

	print -- "$state"
}

# Update the state for all DSRs.
function Dsr_update_state
{
	typeset i key normdscp normvip

	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		normvip=${Dsr_keys[$i]%%,*}
		normdscp=${Dsr_keys[$i]##*,}
		key=$(makekey "$normvip" "$normdscp")
		Dsr[$key].state=$(Dsr_calculate_state "$normvip" "$normdscp")
	done
}

# Initialize a Dsr struct for all discovered DSRs.
function Dsr_init_discovered_dsrs
{
	typeset dscp i key normdscp normvip vip

	for ((i=0; i<${#Iptables_keys[@]}; i++)); do
		normvip=${Iptables_keys[$i]%%,*}
		normdscp=${Iptables_keys[$i]##*,}
		key=$(makekey "$normvip" "$normdscp")
		vip=${Iptables[$key].vipname}
		dscp=${Iptables[$key].dscp}

		! Dsr_is_configured_dsr "$normvip" "$normdscp" || continue
		[[ ${Iptables[$key].iptsrc} == discovered ]] || continue
		[[ ${Lo[$normvip].indx+_} ]] || continue
		[[ ${Lo[$normvip].losrc} == discovered ]] || continue

		# We choose to use the normalized DSCP for discovered iptables
		# entries.
		Dsr_init discovered "$vip" "$normdscp" none none
	done
}

#
# Print a single DSR given its indx into Dsr_keys.
#
function Dsr_print_one_dsr
{
	typeset i=$1

	typeset af dscp dsrtype iptout key loout
	typeset normdscp normvip src state table vip

	extractkey "${Dsr_keys[$i]}" key normvip normdscp
	af=$(addraf "$normvip")

	vip=${Dsr[$key].vipname}

	vprt2 "====== Checking configured DSR $vip=${Dsr[$key].dscp}"

	if [[ ${Lo[$normvip].state} == started ]]; then
		(( af == 4 )) || loout=lo
		(( af == 6 )) || loout=lo:${Lo[$normvip].num}
	else
		loout=--
	fi

	iptout=--
	[[ ! ${Iptables[$key].state+_} ]] || \
		[[ ${Iptables[$key].state} != started ]] || \
		iptout=up

	[[ ${Dsr[$key].dsrsrc} == configured ]] || src=disc
	[[ ${Dsr[$key].dsrsrc} != configured ]] || src=conf

	state=$(Dsr_calculate_state "$normvip" "$normdscp")
	if Dsr_l3dsr "$normvip" "$normdscp"; then
		dsrtype=l3dsr

		# We always print the value provided in the .conf
		# file, not any possible conversion to decimal.
		dscp=${Dsr[$key].dscp}
	else
		dsrtype=l2dsr
		dscp=--
	fi
	emit_data "$dsrtype" \
		  "$state" \
		  "${Dsr[$key].vipname}" \
		  "${Dsr[$key].vipnumeric}" \
		  "$dscp" \
		  "$loout" \
		  "$iptout" \
		  "${Table[print]}" \
		  "$src"

	return 0
}

#
# If something goes wrong while starting the DSRs, we need to undo (stop)
# all of the DSRs we just started.  This function does that cleanup.
#
function Dsr_restore_dsrs_to_orig_state
{
	typeset i key normdscp normvip key save_nofail vip

	Lo_reread_loopbacks
	Iptables_reread_iptables

	# We try as hard as we can to stop the DSRs even if we have
	# some failures.
	save_nofail=$NoFail
	No_Fail=1

	# Remove all of the DSRs that we started.
	#
	for ((i=${#Dsr_keys[@]}-1; i>=0; i--)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp

		# Skip DSRs that weren't read from the config files because if
		# they didn't come from the config files, then we didn't start
		# them.
		[[ ${Dsr[$key].dsrsrc} == configured ]] || continue

		vip=${Dsr[$key].vipname}
		vprt2 "====== Restoring DSR $vip"

		! Dsr_l3dsr "$normvip" "$normdscp" || \
			Iptables_restore_orig_state "$normvip" "$normdscp"
		Lo_restore_orig_state "$normvip"
	done

	NoFail=$save_nofail

	return 0
}
#
# Returns
#   0 if the given ipaddr refers to an L3DSR DSR
#   1 if the given ipaddr refers to an L2DSR DSR
#
function Dsr_l3dsr
{
	typeset normvip=$1
	typeset normdscp=$2

	typeset key=$(makekey "$normvip" "$normdscp")

	[[ ${Dsr[$key].type} == l3dsr ]] || return 1
	return 0
}

# Returns count of configured DSRs (both IPv4 and IPv6).
function Dsr_configured_dsr_count
{
	typeset i normdscp normvip dsrcount=0

	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp

		Dsr_ip_exists "$normvip" "$normdscp" "$i" || continue
		Dsr_is_configured_dsr "$normvip" "$normdscp" || continue

		(( dsrcount++ ))
	done

	print -- "$dsrcount"
}

#
# Validate a DSCP value.  If the DSCP value is invalid, the reason is printed.
# Returns
#   0 if the DSCP value is valid
#   1 if the DSCP value is invalid
#
function Dsr_validate_dscp
{
	typeset dscp=$1
	typeset config_file=$2
	typeset lineno=$3

	typeset str rv=0

	# Empty DSCPs just mean L2DSR, so they're valid.
	[[ -n $dscp ]] || return 0

	# First, test if dscp is numeric.
	if isnumeric "$dscp"; then
		if (( $(normalize_dscp "$dscp") > 63 )); then
			str="Invalid DSCP value at \"$config_file\", line $lineno.  "
			str+="\"$dscp\" too large (max=63)."
			print -- "$str"
			rv=1
		fi
	else
		str="Invalid DSCP value at \"$config_file\", line $lineno.  "
		str+="\"$dscp\" is not an expected number."
		print -- "$str"
		rv=1
	fi

	return $rv
}

# Validate the DSR.
# The vipnumeric and dscp arguments are not normalized.
#
# Returns 0 if everything was OK.
# Returns 1 if duplicate DSRs are found.
# Returns 2 otherwise.
function Dsr_validate_dsr
{
	typeset fqdn=$1
	typeset vipnumeric=$2
	typeset dscp=$3
	typeset config_file=$4
	typeset lineno=$5

	typeset af dupdscp dupdsrtype dupindx key normdscp normvip
	typeset prevdscp prevdsrtype previp prevkey str

	Dsr_validate_dscp "$dscp" "$config_file" "$lineno" || return 2

	normvip=$(normalize_vip "$vipnumeric")
	normdscp=$(normalize_dscp "$dscp")

	if Dsr_find_configured_dsr_by_ip_and_dscp "$normvip" "$normdscp"; then
		# We have found an exact duplicate.
		print -- "Duplicate DSRs found for $vipnumeric."
		Dsr_l3dsr "$normvip" "$normdscp" && dupdsrtype=L3DSR || dupdsrtype=L2DSR

		key=$(makekey "$normvip" "$normdscp")

		str="- Prev: $dupdsrtype at "
		str+="\"${Dsr[$key].config_file}\", "
		str+="line ${Dsr[$key].config_file_lineno}."
		print -- "$str"

		str="- Dup:  $dupdsrtype at \"$config_file\", line $lineno."
		print -- "$str"

		return 1
	fi

	# Check for DSRs that have the same DSCP, but a different IP.
	af=$(addraf "$normvip")
	dupindx=$(Dsr_find_configured_dsr_by_dscp "$normdscp" "$af")
	if [[ $dupindx != notfound ]]; then
		previp=${Dsr_keys[$dupindx]%%,*}

		if [[ -z $dscp ]]; then
			dupdsrtype=L2DSR
			dupdscp=none
		else
			dupdsrtype=L3DSR
			dupdscp=$dscp
		fi

		# Prev: L3DSR  Dup: L3DSR (diff IPs)
		# Prev: L2DSR  Dup: L2DSR (diff IPs)
		prevdsrtype=$dupdsrtype
		prevdscp=$dupdscp

		str="Conflicting DSRs "
		str+="(IP=$previp, IP=$vipnumeric) "
		str+="found with DSCP $prevdscp."
		print -- "$str"

		normdscp=$(normalize_dscp "$dscp")
		prevkey=$(makekey "$previp" "$normdscp")
		str="- Prev: $prevdsrtype at \"${Dsr[$prevkey].config_file}\", "
		str+="line ${Dsr[$prevkey].config_file_lineno}."
		print -- "$str"

		str="- Dup:  $dupdsrtype at \"$config_file\", line $lineno."
		print -- "$str"

		return 2
	fi

	return 0
}

# Return 0 if the $normvip,$normdscp DSR exists and is indexed by the given indx.
# Otherwise, return 1.
function Dsr_ip_exists
{
	typeset normvip=$1
	typeset normdscp=$2
	typeset indx=$3

	typeset key=$(makekey "$normvip" "$normdscp")

	[[ ! ${Dsr[$key].indx+_} ]] || [[ ${Dsr[$key].indx} != $indx ]] || \
		return 0

	return 1
}

# Return 0 if $normvip,$normdscp is a configured DSR.
function Dsr_is_configured_dsr
{
	typeset normvip=$1
	typeset normdscp=$2

	typeset key=$(makekey "$normvip" "$normdscp")

	[[ ! ${Dsr[$key].dsrsrc+_} ]] || [[ ${Dsr[$key].dsrsrc} != configured ]] || \
		return 0

	return 1
}

# Search all configured DSRs for the given normalized VIP and DSCP.
# Returns
#     0  if given VIP/DSCP was found
#     1  if given VIP/DSCP was not found
function Dsr_find_configured_dsr_by_ip_and_dscp
{
	typeset normvip=$1
	typeset normdscp=$2

	typeset key=$(makekey "$normvip" "$normdscp")

	[[ ${Dsr[$key].indx+_} ]] || Dsr_is_configured_dsr "$normvip" "$normdscp" || \
		return 1

	return 0
}

# Search for just the DSCP value in the configured
# DSRs.  We use this to search for duplicate DSCPs in
# the config files.
# Don't bother to search for L2DSRs -- they all have an
# empty DSCP.
function Dsr_find_configured_dsr_by_dscp
{
	typeset normdscparg=$1
	typeset afarg=$2

	typeset i key normdscp normvip

	[[ -n $normdscparg ]] || { print -- "notfound"; return 0; }

	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp

		[[ ${Dsr[$key].dsrsrc} == configured ]] || continue
		[[ $normdscp == $normdscparg ]] || continue
		[[ $afarg == $(addraf "$normvip") ]] || continue

		# If we get here, then we found one.
		print -- "$i"
		return 0
	done

	print -- "notfound"
	return 0
}

# Search for just the VIP address in the configured DSRs.
# This function only finds the first matching entry.
function Dsr_find_discovered_dsr_by_vip
{
	typeset normvip_arg=$1

	typeset i key normdscp normvip

	[[ -n $normvip_arg ]] || { print -- "notfound"; return 0; }

	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp

		[[ ${Dsr[$key].dsrsrc} == discovered ]] || continue
		[[ $normvip_arg == $normvip ]] || continue

		print -- "$i"
		return 0
	done

	print -- "notfound"
	return 0
}

function Dsr_dbg_print
{
	typeset af dscp dsrsrc i key normdscp normvip state vip

	Dsr_read_configuration || return 1

	vprt2 "====== Config File Start"
	vprt2 "======     Number of DSRs = $(Dsr_configured_dsr_count)"
	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp

		[[ ${Dsr[$key].dsrsrc} == configured ]] || continue

		af=$(addraf "$normvip")
		state=${Dsr[$key].state}
		dsrsrc=${Dsr[$key].dsrsrc}
		vip=${Dsr[$key].vipname}
		dscp=${Dsr[$key].dscp}
		vprt2 "======         dsr$af: $dsrsrc $state vip=$vip dscp=$dscp"
	done

	vprt2 "====== Config File End"

	return 0
}

# =======================================================================
# End of Dsr
# =======================================================================


# =======================================================================
# Lo
# =======================================================================

# Initialize the given loopback.
function Lo_init
{
	typeset losrc=$1
	typeset vipnumeric=$2
	typeset vip=$3
	typeset lonum=$4

	typeset indx normvip

	# Now we create a new Loopback.
	indx=${#Lo_keys[@]}

	normvip=$(normalize_vip "$vipnumeric")

	Lo_keys[$indx]=$normvip
	Lo[$normvip].indx=$indx
	Lo[$normvip].vipname=$vip
	Lo[$normvip].vipnumeric=$vipnumeric
	Lo[$normvip].state=init
	Lo[$normvip].state_orig=init
	Lo[$normvip].losrc=$losrc
	Lo[$normvip].num=$lonum

	return 0
}

#
# Start a loopback.
#
# Returns
#   0 if the loopback was successfully started
#   1 otherwise
#
function Lo_start
{
	typeset normvip=$1

	typeset af aliasincrement lonum rv=0 vip
	typeset -a cmd

	[[ ${Lo[$normvip].state} == stopped ]] || return 0

	Lo[$normvip].state=starting

	if [[ $NoRun == yes ]]; then
		(( aliasincrement = ++FakeAliasIncrement ))
	else
		aliasincrement=0
	fi

	lonum=$(Lo_get_loopback_alias "$aliasincrement" || rv=$?)
	if (( rv != 0 )); then
		Lo[$normvip].state=error
		print -- "Cannot find available loopback alias."
		return 1
	fi

	Lo[$normvip].num=$lonum

	af=$(addraf "$normvip")
	vip=${Lo[$normvip].vipname}
	vipnumeric=${Lo[$normvip].vipnumeric}
	(( af == 4 )) || cmd=(ip addr add $vip/128 dev lo)
	(( af == 6 )) || cmd=(ip addr add $vipnumeric/32 dev lo label lo:$lonum)

	if run "${cmd[@]}"; then
		Lo[$normvip].state=started
	else
		Lo[$normvip].state=error
		unset Lo[$normvip].num
		print -- "Failed to start loopback for $vip."
		rv=1
	fi

	return $rv
}

#
# Stop a loopback.
#
# Returns
#   0 if the loopback was successfully stopped or was not in the
#     started state when the function was called.
#   1 otherwise
#
function Lo_stop
{
	typeset normvip=$1

	typeset af rv=0 vip
	typeset -a cmd

	[[ ${Lo[$normvip].state} == started ]] || return 0

	Lo[$normvip].state=stopping

	af=$(addraf "$normvip")
	vip=${Lo[$normvip].vipname}
	vipnumeric=${Lo[$normvip].vipnumeric}
	(( af == 4 )) || cmd=(ip addr del $vip/128 dev lo)
	(( af == 6 )) || cmd=(ip addr del $vipnumeric/32 dev lo label lo:${Lo[$normvip].num})

	if run "${cmd[@]}"; then
		Lo[$normvip].state=stopped
	else
		Lo[$normvip].state=error
		rv=1
	fi

	return $rv
}

# Restore the original state (before we tried to start DSRs) of the loopback.
function Lo_restore_orig_state
{
	typeset normvip=$1

	if [[ ${Lo[$normvip].state_orig} == stopped ]]; then
		[[ ${Lo[$normvip].state} != started ]] || Lo_stop "$normvip"
	fi
	if [[ ${Lo[$normvip].state_orig} == started ]]; then
		[[ ${Lo[$normvip].state} != stopped ]] || Lo_start "$normvip"
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
# If we're not running commands ($NoRun==yes), then just create fake, but
# reasonable, numbers.  This is controlled by the aliasincrement.  It's 0 when
# we're running commands and artifically increases when we're not.
#
# Returns
#   0 if no failures were found
#     Prints the max alias value
#   1 if we failed to successfully read the loopback information
#     Prints nothing
#
function Lo_get_loopback_alias
{
	typeset aliasincrement=$1

	typeset i normvip max=0 newalias

	# We need to reread the loopbacks because they might have changed
	# since we started or, if we are starting multiple DSRs, since the
	# last DSR that we started.
	Lo_reread_loopbacks || return 1

	for ((i=0; i<${#Lo_keys[@]}; i++)); do
		normvip=${Lo_keys[$i]}
		[[ ${Lo[$normvip].state} == started ]] || continue

		# IPv6 loopback aliases don't have a lonum value
		# so we check for empty values and skip the max
		# calculation for IPv6 loopback aliases.
		[[ ! ${Lo[$normvip].num+_} ]] || \
		{ (( $(addraf "$normvip") == 6 )) && [[ -z ${Lo[$normvip].num} ]]; } || \
		(( ${Lo[$normvip].num} <= max )) || \
			max=${Lo[$normvip].num}
	done

	[[ $NoRun == yes ]] || (( max++ ))

	(( newalias = max + aliasincrement )) || :
	print -- "$newalias"

	return 0
}

#
# Get all of the loopbacks running on the machine and fill in state
# information if they are configured DSRs.  This works for both IPv4 and IPv6
# loopbacks.
#
function Lo_get_loopbacks
{
	typeset i indx ipout line lines lo loaf loinfo loname lonum
	typeset normvip oifs vip vipinfo vipnumeric

	(( GotLoopbacksAlready == 0 )) || return 0

	GotLoopbacksAlready=1

	# Run the vip program to get the loopback information.
	# $? is the return value of the rightmost cmd that fails or zero otherwise.
	# This is usually the egrep.
	ipout=$(run ip -o addr show lo)
	(( $? < 2 )) || return 1

	oifs=$IFS
	IFS=$'\n'
	lines=( $(print -- "$ipout") )
	IFS=$oifs

	# Expecting output like this from the ip cmd.
	#     1: lo    inet 188.125.67.68/32 brd 188.125.67.68 scope global lo:1
	#     1: lo    inet 188.125.82.253/32 brd 188.125.82.253 scope global lo:2
	#     1: lo    inet 188.125.82.38/32 brd 188.125.82.38 scope global lo:3
	#     1: lo    inet 188.125.82.196/32 brd 188.125.82.196 scope global lo:4
	#
	# It's a little different for RHEL7.
	#     1: lo    inet 188.125.67.68/32 scope global lo:1\ valid_lft forever preferred_lft forever

	for line in "${lines[@]}"; do
		# Skip lines we don't care about.
		[[ $line != *127.0.0.1* ]] || continue
		[[ $line != *LOOPBACK* ]] || continue
		[[ $line != *::1/128* ]] || continue

		# Remove all backslashes in line.
		line=${line//\\/}

		lo=($line)
		loaf=${lo[2]}
		if [[ $loaf == inet ]]; then
			# Find the "scope" element.  The loopback name is
			# two elements later.
			indx=-1
			for ((i=0; i<${#lo[@]}; i++)); do
				[[ ${lo[$i]} == scope ]] || continue

				(( indx = i + 2 ))
				break
			done

			# Skip this line if we didn't find the "scope" element.
			(( indx >= 2 )) || continue

			loinfo=${lo[$indx]}
			loname=${loinfo%%:*}
			lonum=${loinfo##${loname}:}

			vipinfo=${lo[3]}
			vip=${vipinfo%%/*}
			[[ -n $lonum ]] || continue
		else
			# inet6
			vip=${lo[3]}
			vip=${vip%%/*}
			lonum=
		fi
		[[ -n $vip ]] || continue

		normvip=$(normalize_vip "$vip")
		if [[ ${Lo[$normvip].indx+_} ]]; then
			Lo[$normvip].num=$lonum
			Lo[$normvip].vipname=$vip
		else
			Lo_init discovered "$vip" "$vip" "$lonum"
		fi

		[[ ${Lo[$normvip].state_orig} != init ]] || Lo[$normvip].state_orig=started
		Lo[$normvip].state=started
	done

	for ((i=0; i<${#Lo_keys[@]}; i++)); do
		normvip=${Lo_keys[$i]}
		[[ ${Lo[$normvip].state} != init ]] || Lo[$normvip].state=stopped
		[[ ${Lo[$normvip].state_orig} != init ]] || Lo[$normvip].state_orig=stopped

		[[ ${Lo[$normvip].losrc} != configured ]] || continue

		vip=${Lo[$normvip].vipname}
		vipnumeric=${Lo[$normvip].vipnumeric}

		update_maxlen ipall   ${#vipnumeric}
		update_maxlen nameall ${#vip}
		if [[ ${Lo[$normvip].losrc} == configured ]]; then
			update_maxlen ipconf   ${#vipnumeric}
			update_maxlen nameconf ${#vip}
		fi
	done

	return 0
}

# Retrieve the loopback information again and update data structures.
function Lo_reread_loopbacks
{
	GotLoopbacksAlready=0

	Lo_get_loopbacks
	Dsr_update_state
}

# Print unconfigured loopbacks.
function Lo_print_unconfigured
{
	typeset af i loout normvip vip

	for ((i=0; i<${#Lo_keys[@]}; i++)); do
		normvip=${Lo_keys[$i]}
		[[ ${Lo[$normvip].losrc} != configured ]] || continue

		vip=${Lo[$normvip].vipname}

		# If the Dsr entry for this key exists, then it has already
		# been printed, either as a configured entry or as a
		# discovered entry.
		[[ $(Dsr_find_discovered_dsr_by_vip "$normvip") == notfound ]] || continue

		if [[ ${Lo[$normvip].state} == started ]]; then
			af=$(addraf "$normvip")
			(( af == 4 )) || loout=lo
			(( af == 6 )) || loout=lo:${Lo[$normvip].num}
		else
			loout=--
		fi

		emit_data "loopb" \
			  "${Lo[$normvip].state}" \
			  "$vip" \
			  "$vip" \
			  "--" \
			  "$loout" \
			  "--" \
			  "--" \
			  "disc"
	done
}

function Lo_dbg_print
{
	typeset af i losrc lonum normvip state vip

	Lo_get_loopbacks || return 1

	vprt2 "====== Loopbacks Start"
	vprt2 "======     Number of loopbacks = ${#Lo_keys[@]}"
	for ((i=0; i<${#Lo_keys[@]}; i++)); do
		normvip=${Lo_keys[$i]}
		af=$(addraf "$normvip")
		losrc=${Lo[$normvip].losrc}
		lonum=${Lo[$normvip].num}
		state=${Lo[$normvip].state}
		vip=${Lo[$normvip].vipname}
		if (( af == 4 )); then
			[[ -z $lonum ]] || lonum=" $lonum"
			vprt2 "======         loopback$af: $losrc $state vip=$vip$lonum"
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

# Initialize an iptables struct
# dscp is not normalized.
function Iptables_init
{
	typeset iptsrc=$1
	typeset vipnumeric=$2
	typeset vip=$3
	typeset dscp=$4

	typeset indx key

	# Now we create a new Iptables.
	indx=${#Iptables_keys[@]}

	key=$(makekey_normalized "$vipnumeric" "$dscp")

	Iptables_keys[$indx]=$key
	Iptables[$key].indx=$indx
	Iptables[$key].dscp=$dscp
	Iptables[$key].vipname=$vip
	Iptables[$key].vipnumeric=$vipnumeric
	Iptables[$key].state=init
	Iptables[$key].state_orig=init
	Iptables[$key].iptsrc=$iptsrc
	Iptables[$key].rulecnt=1
	Iptables[$key].dup_warn_emitted=0

	return 0
}

#
# Get iptables/ip6tables information given the address family (4/6)
# and the iptables table.
#
# Other rules that might be running from other tables are ignored.
#
function Iptables_get_iptables_af_table
{
	typeset af=$1

	typeset cmd conf_normdscp dscp dscp_val i
	typeset iptablesout iptbl key line lines normdscp normvip oifs
	typeset pgm skip_vip_adjust=0 skipchain=1 str vip vipnumeric
	typeset -A fldnum

	# Skip getting IPv6 status if IPv6 is disabled.
	# ip6tables just fails on RHEL7 and earlier if IPv6 is disabled.
	(( af == 4 )) || ! ip6_disabled || return 0

	(( af == 4 )) && pgm=iptables || pgm=ip6tables

	cmd=($pgm -L -t "${Table[val]}" -n)

	iptablesout=$(run "${cmd[@]}" 2>&1)
	(( $? < 2 )) || { print -u2 -- "Failed to get $pgm (${cmd[@]})."; return 1; }

	oifs=$IFS
	IFS=$'\n'
	lines=( $(print -- "$iptablesout") )
	IFS=$oifs

	# Expecting output like this from the iptables cmd.
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x1cDADDR set 188.125.67.68
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x11DADDR set 188.125.82.253
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x13DADDR set 188.125.82.38
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x2bDADDR set 188.125.82.196
	#
	# On some RHEL versions (RHEL5, RHEL8), it's slightly different.
	#  DADDR      all  --  anywhere    anywhere    DSCP match 0x1c DADDR set 188.125.67.68
	#
	# Expecting output like this from the ip6tables cmd.
	# Sadly, it's a bit different from the iptables cmd.
	#  DADDR      all      anywhere    anywhere    DSCP match 0x24DADDR set 2001:4998:c:a06::2:4002
	#  DADDR      all      anywhere    anywhere    DSCP match 0x16DADDR set 2001:4998:c:a06::2:4003
	#  DADDR      all      anywhere    anywhere    DSCP match 0x18DADDR set 2001:4998:c:a06::2:4004
	#
	# On some RHEL versions (RHEL5, RHEL8), it's slightly different.
	#  DADDR      all      anywhere    anywhere    DSCP match 0x18 DADDR set 2001:4998:c:a06::2:4004

	# Initialize the expected field numbers for the fields that we care about.
	if (( af == 4 )); then
		fldnum[dscp]=5
		fldnum[match]=6
		fldnum[dscp_val]=7
		fldnum[vip]=9
	else
		fldnum[dscp]=4
		fldnum[match]=5
		fldnum[dscp_val]=6
		fldnum[vip]=8
	fi

	# Read each iptables output line and process.
	for line in "${lines[@]}"; do
		iptbl=($line)

		# We only care about the $IptablesChain chain.  Rules in any
		# other chains are ignored.
		if [[ ${iptbl[0]} == Chain ]]; then
			[[ ${iptbl[1]} == $IptablesChain ]] && skipchain=0 || skipchain=1
			continue
		fi

		(( skipchain == 0 )) || continue
		[[ ${iptbl[0]} == DADDR ]] || continue
		[[ ${iptbl[${fldnum[dscp]}]} == DSCP ]] || continue
		[[ ${iptbl[${fldnum[match]}]} == match ]] || continue

		dscp_val=${iptbl[${fldnum[dscp_val]}]}
		dscp=${dscp_val%%DADDR}

		# Check if the match value and "DADDR" are pushed together.
		# If not, then adjust fldnum[vip].  We only have to make
		# the adjustment once.
		(( skip_vip_adjust )) ||
			{ [[ $dscp != $dscp_val ]] || (( fldnum[vip]++ )); skip_vip_adjust=1; }

		vip=${iptbl[${fldnum[vip]}]}

		[[ -n $dscp ]] || continue
		[[ -n $vip  ]] || continue

		normvip=$(normalize_vip "$vip")
		normdscp=$(normalize_dscp "$dscp")
		key=$(makekey "$normvip" "$normdscp")

		# Check for duplicate iptables rules and increment the count
		# of rulecnt.
		[[ ! ${Iptables[$key].indx+_} ]] || (( Iptables[$key].rulecnt++ ))

		# The iptables/ip6tables commands produce output that contains
		# numeric IP addresses, so we use the given vip for both
		# vipname and vipnumeric when calling Iptables_init.  We
		# don't want to use the normalized VIP for either vipname or
		# vipnumeric.
		[[ ${Iptables[$key].indx+_} ]] || \
			Iptables_init discovered "$vip" "$vip" "$dscp"

		conf_normdscp=$(normalize_dscp "${Iptables[$key].dscp}")
		if (( conf_normdscp != normdscp )); then
			str="Configured DSCP value "
			str+="(vip=$vip, dscp=${Iptables[$key].dscp}) "
			str+="does not match started DSCP value "
			str+="(vip=$vip, dscp=$dscp)."
			print -- "$str"
			continue
		fi

		[[ ${Iptables[$key].state_orig} != init ]] || \
			Iptables[$key].state_orig=started
		Iptables[$key].state=started
	done

	for ((i=0; i<${#Iptables_keys[@]}; i++)); do
		extractkey "${Iptables_keys[$i]}" key normvip normdscp

		vip=${Iptables[$key].vipname}
		vipnumeric=${Iptables[$key].vipnumeric}
		dscp=${Iptables[$key].dscp}

		[[ ${Iptables[$key].state} != init ]] || Iptables[$key].state=stopped
		[[ ${Iptables[$key].state_orig} != init ]] || Iptables[$key].state_orig=stopped

		# Check for duplicate iptables rules.  It is possible to
		# successfully run iptables/ip6tables multiple times with the
		# same rule.  While not strictly an error, it is an indication
		# that something has gone wrong when starting the VIPs, so we
		# emit a warning message.
		if (( ${Iptables[$key].rulecnt} > 1 )) && \
		   (( ${Iptables[$key].dup_warn_emitted} == 0 ))
		then
			if (( AllOpt == 1 )) || \
			   [[ ${Iptables[$key].iptsrc} == configured ]]
			then
				str="Duplicate iptables rules found for VIP $vip=$dscp "
				str+="count=${Iptables[$key].rulecnt}"
				print -- "$str"
				Iptables[$key].dup_warn_emitted=1
			fi
		fi

		update_maxlen ipall      ${#vipnumeric}
		update_maxlen nameall    ${#vip}
		update_maxlen tblnameall ${#Table[print]}
		if [[ ${Iptables[$key].iptsrc} == configured ]]; then
			update_maxlen ipconf      ${#vipnumeric}
			update_maxlen nameconf    ${#vip}
			update_maxlen tblnameconf ${#Table[print]}
		fi
	done
}

# Get all of the iptables information.
function Iptables_get_iptables
{
	typeset af i key normdscp normvip

	(( GotIptablesAlready == 0 )) || return 0

	GotIptablesAlready=1

	# Zero out the rulecnt counts.  Because this function may be called
	# multiple times during the execution of the script, we need to zero
	# the counts out each time.
	for ((i=0; i<${#Iptables_keys[@]}; i++)); do
		extractkey "${Iptables_keys[$i]}" key normvip normdscp
		Iptables[$key].rulecnt=0
	done

	Iptables_get_iptables_af_table 4 || return 1
	Iptables_get_iptables_af_table 6 || return 1

	return 0
}

# Get all of the iptables information and update data structures.
function Iptables_reread_iptables
{
	GotIptablesAlready=0

	Iptables_get_iptables
	Dsr_update_state
}

#
# Start an iptables/ip6tables rule.
#
# Returns
#   0 if the iptables rule was successfully started or was not in the
#     stopped state when the function was called.
#   1 otherwise
#
function Iptables_start
{
	typeset normvip=$1
	typeset normdscp=$2

	typeset af dscp key loc pgm rv=0 vipnumeric
	typeset -a cmd

	key=$(makekey "$normvip" "$normdscp")
	[[ ${Iptables[$key].state} == stopped ]] || return 0

        # Note that it's not necessary to check for ip6_disabled here because
        # Iptables_start never gets called when IPv6 is disabled.
	af=$(addraf "$normvip")
	(( af == 4 )) && pgm=iptables || pgm=ip6tables

	vipnumeric=${Iptables[$key].vipnumeric}
	dscp=${Iptables[$key].dscp}

	[[ $InsertMode == yes ]] && loc=I || loc=A

	cmd=($pgm -t "${Table[val]}" \
	          -$loc "$IptablesChain" \
	          -m dscp \
	          --dscp "$dscp" \
	          -j DADDR \
	          "--set-daddr=$vipnumeric")

	Iptables[$key].state=starting
	if run "${cmd[@]}"; then
		Iptables[$key].state=started
	else

		Iptables[$key].state=error
		print -- "Failed to start iptables rule in table " \
		         "${Table[val]} for $vipnumeric=$dscp."
		rv=1
	fi

	return $rv
}

#
# Stop an iptables/ip6tables rule.
#
# Returns
#   0 if the iptables rule was successfully stopped or was not in the
#     started state when the function was called.
#   1 otherwise
#
function Iptables_stop
{
	typeset normvip=$1
	typeset normdscp=$2

	typeset af dscp key pgm rv=0 vipnumeric
	typeset -a cmd

	key=$(makekey "$normvip" "$normdscp")
	[[ ${Iptables[$key].state} == started ]] || return 0

	[[ -n $normdscp ]] || return 0

	Iptables[$key].state=stopping

	vipnumeric=${Iptables[$key].vipnumeric}
	dscp=${Iptables[$key].dscp}

        # Note that it's not necessary to check for ip6_disabled here because
        # Iptables_stop never gets called when IPv6 is disabled.
	af=$(addraf "$normvip")
	(( af == 4 )) && pgm=iptables || pgm=ip6tables

	cmd=($pgm -t "${Table[val]}" \
	          -D "$IptablesChain" \
	          -m dscp \
	          --dscp "$dscp" \
	          -j DADDR \
	          "--set-daddr=$vipnumeric")

	while (( ${Iptables[$key].rulecnt} > 0 )); do
		if run "${cmd[@]}"; then
			(( Iptables[$key].rulecnt-- ))
		else
			Iptables[$key].state=error
			rv=1
			break
		fi
	done

	(( rv != 0 )) || Iptables[$key].state=stopped

	return $rv
}

# Restore the original state (before we tried to start DSRs) of the iptables entry.
function Iptables_restore_orig_state
{
	typeset normvip=$1
	typeset normdscp=$2

	typeset key

	key=$(makekey_normalized "$normvip" "$normdscp")
	if [[ ${Iptables[$key].state_orig} == stopped ]]; then
		[[ ${Iptables[$key].state} != started ]] || Iptables_stop "$normvip" "$normdscp"
	fi
	if [[ ${Iptables[$key].state_orig} == started ]]; then
		[[ ${Iptables[$key].state} != stopped ]] || Iptables_start "$normvip" "$normdscp"
	fi
}

# Print all unconfigured iptables entries.
function Iptables_print_unconfigured
{
	typeset i key normdscp normvip iptout vip

	for ((i=0; i<${#Iptables_keys[@]}; i++)); do
		extractkey "${Iptables_keys[$i]}" key normvip normdscp

		[[ ${Iptables[$key].iptsrc} != configured ]] || continue

		# If the Dsr entry for this key exists, then it has already
		# been printed, either as a configured entry or as a
		# discovered entry.
		[[ ! ${Dsr[$key].dsrsrc+_} ]] || continue

		[[ ${Iptables[$key].state} == started ]] || iptout=--
		[[ ${Iptables[$key].state} != started ]] || iptout=up

		vip=${Iptables[$key].vipname}

		emit_data "iptbl" \
			  "${Iptables[$key].state}" \
			  "$vip" \
			  "$vip" \
			  "${Iptables[$key].dscp}" \
			  "--" \
			  "$iptout" \
			  "${Table[print]}" \
			  "disc"
	done
}

function Iptables_dbg_print
{
	typeset af i iptsrc key normdscp normvip state vip

	Iptables_get_iptables || return 1

	vprt2 "====== Iptables Start"
	vprt2 "======     Number of iptables rules = ${#Iptables_keys[@]}"
	for ((i=0; i<${#Iptables_keys[@]}; i++)); do
		extractkey "${Iptables_keys[$i]}" key normvip normdscp
		vip=${Iptables[$key].vipname}

		af=$(addraf "$normvip")
		iptsrc=${Iptables[$key].iptsrc}
		state=${Iptables[$key].state}
		vprt2 "======         iptables${af}: $iptsrc $state vip=$vip dscp=${Iptables[$key].dscp}"
	done

	vprt2 "====== Iptables End"

	return 0
}

# =======================================================================
# End of Iptables
# =======================================================================

# Set the default iptables table.
#
# The default default is mangle for historical reasons.  If $DaddrTableFile exists,
# then the kernel module exposes which table it is using in that file.
#
# Note that $DaddrTableFile doesn't exist until the module is loaded, so even
# if loading the module might default to using raw, this script defaults to
# mangle until the module is loaded.
function set_iptables_table
{
	typeset table vcmt

	if [[ -e "$DaddrTableFile" ]]; then
		if [[ ! -r "$DaddrTableFile" ]]; then
			print -u2 -- "Cannot read $DaddrTableFile.  Exiting."
			exit 1;
		fi

		Table[state]=detected
		Table[val]=$(< "$DaddrTableFile")
		Table[print]=${Table[val]}
		vcmt="kmod is loaded, using $DaddrTableFile"

	elif kmod_is_loaded; then

		Table[state]=loaded
		Table[val]=$DfltTable
		Table[print]=${Table[val]}
		vcmt="kmod is loaded, using default"

	else
		Table[state]=unloaded
		Table[val]=mangle
		Table[print]=--
		vcmt="kmod is unloaded, using default default"
	fi

	update_maxlen tblnameall  ${#Table[print]}
	update_maxlen tblnameconf ${#Table[print]}

	vprt2 "===== Iptables Table is ${Table[val]} ($vcmt)"
}

# We keep the max length of column entries in the Maxlen associative array.
# Initialize them to zero here.
function initialize_maxlens
{
	typeset name t

	for t in all conf; do
		for name in ip name tblname; do
			Maxlen[$name$t]=0
		done
	done
}

# Update the maxlen for the given name if appropriate.
function update_maxlen
{
	typeset name=$1
	typeset val=$2

	(( val <= ${Maxlen[$name]} )) || Maxlen[$name]=$val
}

# Return 0 if the xt_DADDR module is loaded.
# Return 1 if the xt_DADDR module is not loaded.
function kmod_is_loaded
{
	[[ -r /proc/modules ]] || { echo "Can't read /proc/modules.  Exiting."; exit 1; }
	egrep -qw "^$Kmod" /proc/modules
}

#
# Load the xt_DADDR kernel module if it's not already loaded.
#
# This script tries to load the kernel module whenever it is run with an
# action that can change the state of the iptables.  The kernel module is
# loaded so that we don't have to guess what iptables table is being used.
# Adding iptables rules with the wrong table confuses the kernel module loader
# if it has to load the kernel module and can make unloading the kernel module
# more difficult.
#
# Note that any kernel module options that are necessary for xt_DADDR must be
# specified in /etc/modprobe.d.  For example, if you want to use a table other
# than the default, then specify that in a .conf file in /etc/modprobe.d.
# Don't use the command line option to set the option because the kernel
# module can be loaded automatically (e.g., when running iptables) and the
# options won't be used.
#
function load_kmod
{
	typeset out rv

	# Only load the module once.
	(( !KmodLoaded )) || return 0

	! kmod_is_loaded || { KmodLoaded=1; return 0; }

	out=$(run modprobe $Kmod 2>&1)
	rv=$?
	(( rv == 0 )) && KmodLoaded=1 || vprt3 "$out"

	return $rv
}

# Remove the xt_DADDR kernel module.
#
# We utilize a loop with a sleep because of the changes in behavior between
# RHEL7 and RHEL8.  In RHEL7, one could remove the last iptables entry related
# to xt_DADDR and immediately remove the the module.  In RHEL8, the module is
# not immediately removeable and fails with this message.
#     modprobe: FATAL: Module xt_DADDR is in use.
#
# The module removal eventually succeeds.  Without any intervening sleeps, it
# takes up to 20 "modprobe -r" attempts to finally succeed on RHEL8.
#
# In tests, the "modprobe -r" can take up to 41ms after the return of the last
# iptables rule removal before succeeding.
#
# SleepInit and SleepLoop were added solely to let the verbose.d tests pass.
# By increasing the sleep values, the number of "modprobe -r" calls is limited
# to one and the output matches for both RHEL7 and RHEL8.
#
# The default values for SleepInit and SleepLoop are chosen so that there is
# no delay before the first attempt to remove the module and subsequent delays
# are short enough to not overly harm the script's performance, but always
# result in the successful removal of the xt_DADDR module.
#
# Yes, this is ugly.  I hate delays.
function remove_kmod
{
	typeset i out rv slp

	[[ $KeepModule == no ]] || return 0

	# The default value for i and the sleep values should result in a
	# maximum delay of 2 seconds.
	for ((i=0; i<8; i++)); do
		(( i == 0 )) && slp=$SleepInit || slp=$SleepLoop
		(( slp <= 0.0 )) || sleep $slp
		out=$(run modprobe -r $Kmod 2>&1)
		rv=$?
		(( rv )) || break
	done

	# Only emit one failure line.
	(( rv )) || vprt3 "$out"

	return $rv
}


# Global initialization.
function init
{
	typeset rv=0 norun_save=$NoRun

	NoRun=no

	initialize_maxlens
	set_iptables_table

	Dsr_read_configuration || \
		{ rv=1 && (( NoFail == 1 )) } || \
		{ NoRun=$norun_save; return 1; }

	Dsr_dbg_print || :

	Lo_get_loopbacks || \
		{ rv=1 && (( NoFail == 1 )); } || \
		{ NoRun=$norun_save; return 1; }

	Lo_dbg_print

	Iptables_get_iptables || \
		{ rv=1 && (( NoFail == 1 )); } || \
		{ NoRun=$norun_save; return 1; }

	Iptables_dbg_print

	Dsr_init_discovered_dsrs

	Dsr_update_state

	NoRun=$norun_save

	return $rv
}

# Check DSR status.
function status
{
	typeset i key normdscp normvip rv=0

	# Continue on through all of the status even if some parts
	# of it fail.  Get everything we can.
	NoFail=1

	init || rv=$?

	# Check all of the DSRs.
	(( $(Dsr_configured_dsr_count) > 0 )) || (( AllOpt != 0 )) ||
		{ print -- "No configured DSRs found."; return 0; }

	(( ${#Lo_keys[@]} > 0 )) || (( ${#Iptables_keys[@]} > 0 )) ||
		{ print -- "No loopback aliases or iptables rules found."; return 0; }

	[[ $NoHeader == yes ]] || Dsr_print_dsr_header

	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp

		(( AllOpt == 1 )) || [[ ${Dsr[$key].dsrsrc} == configured ]] || continue
		Dsr_print_one_dsr "$i" || rv=1
	done

	(( AllOpt == 0 )) || { Lo_print_unconfigured; Iptables_print_unconfigured; }

	return $rv
}

# Display a one line DSR status.
# Returns
#   0 if all of the configured DSRs are started.
#   1 if none of the configured DSRs is started or if an error occurred
#         in processing the configuration file or obtaining the loopbacks
#         or iptables rules.
#   3 if some, but not all configured DSRs are started.
function check
{
	typeset i key normdscp normvip num_started=0 rv=0

	# Continue on through all of the status even if some parts
	# of it fail.  Get everything we can.
	NoFail=1

	init >/dev/null 2>&1 || \
		{ rv=$?; print -u2 -- "DSR configuration error discovered."; return $rv; }

	# Check all of the DSRs.
	(( $(Dsr_configured_dsr_count) > 0 )) || \
		{ print -- "No configured DSRs found."; return 3; }

	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp

		# Skip DSRs that weren't read from the config files.
		[[ ${Dsr[$key].dsrsrc} == configured ]] || continue

		[[ ${Dsr[$key].state} != started ]] || (( num_started++ )) || :
	done

	if (( num_started == 0 )); then
		print -- "No DSRs started."
		rv=1
	elif (( num_started == ${#Dsr_keys[@]} )); then
		print -- "All DSRs started."
	else
		print -- "Some DSRs not started."
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
# of the DSRs when we started.  If we started a DSR, then it is stopped.
# Loopbacks and iptables rules that were not started by this script are
# left unchanged.
#
# Returns
#   0 if all configured DSRs are successfully started
#   1 otherwise
#
function startdsrs
{
	typeset i normdscp normvip key rv=0 vip

	# We need to load the kernel module before doing anything so that we
	# can find out which iptables table to use.
	load_kmod || return 1

	init || return 1

	# Start all of the configured DSRs.
	for ((i=0; i<${#Dsr_keys[@]}; i++)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp
		vip=${Dsr[$key].vipname}

		# Skip DSRs that weren't read from the config files.
		[[ ${Dsr[$key].dsrsrc} == configured ]] || continue

		# Skip IPv6 DSRs if IPv6 is disabled.
		af=$(addraf "$normvip")
		(( af == 4 )) || ! ip6_disabled || continue

		vprt2 "====== Starting DSR $vip=$normdscp"

		[[ ${Dsr[$key].state} != started ]] || continue

		Dsr[$key].state=starting

		! Dsr_l3dsr "$normvip" "$normdscp" || \
		Iptables_start "$normvip" "$normdscp" || \
			{ Dsr[$key].state=error; rv=1; break; }

		Lo_start "$normvip" || \
			{ Dsr[$key].state=error; rv=1; break; }

		Dsr[$key].state=started
	done

	(( rv == 0 )) || Dsr_restore_dsrs_to_orig_state

	return $rv
}

function stopdsrs
{
	typeset dscp i key normdscp normvip vip

	# We try as hard as we can to stop the DSRs even if we have
	# some failures.
	No_Fail=1

	init || :

	# Stop all of the DSRs in reverse order.
	for ((i=${#Dsr_keys[@]}-1; i>=0; i--)); do
		extractkey "${Dsr_keys[$i]}" key normvip normdscp
		vip=${Dsr[$key].vipname}

		# Skip DSRs that weren't read from the config files.
		[[ ${Dsr[$key].dsrsrc} == configured ]] || continue

		# Skip IPv6 DSRs if IPv6 is disabled.
		af=$(addraf "$normvip")
		(( af == 4 )) || ! ip6_disabled || continue

		vprt2 "====== Stopping DSR $vip=${Dsr[$key].dscp}"

		! Dsr_l3dsr "$normvip" "$normdscp" || \
			Iptables_stop "$normvip" "$normdscp"
		Lo_stop "$normvip"
	done

	# If $AllOpt is set, then remove all the DSRs we can find.
	(( AllOpt == 1 )) || { remove_kmod; return 0; }

	Iptables_reread_iptables
	Lo_reread_loopbacks

	for ((i=0; i<${#Iptables_keys[@]}; i++)); do
		extractkey "${Iptables_keys[$i]}" key normvip normdscp
		vip=${Iptables[$key].vipname}
		dscp=${Iptables[$key].dscp}
		vprt2 "====== Removing iptables rule $vip=$dscp"
		Iptables_stop "$normvip" "$normdscp"
	done

	for ((i=0; i<${#Lo_keys[@]}; i++)); do
		vprt2 "====== Removing loopback alias ${Lo_keys[$i]}"
		Lo_stop "${Lo_keys[$i]}"
	done

	remove_kmod

	return 0
}

#
# cleanup is called when the script is terminated prematurely. It cleans up
# whatever mess there is.
#
function cleanup
{
	Dsr_restore_dsrs_to_orig_state

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
InsertMode=no
KeepModule=no
NoFail=0
NoRun=no
SleepInit=0.0
SleepLoop=0.25
VerboseLevel=0
while getopts -a "$ScriptName" ad:f:hikns:vx OPTION; do
    case $OPTION in
	a)      AllOpt=1
		;;
	d)      ConfigDir=$OPTARG
		;;
	f)      ConfigFile=$OPTARG
		;;
	i)      InsertMode=yes
		;;
	k)      KeepModule=yes
		;;
	n)      NoRun=yes
		;;
	s)      s_opt=$OPTARG
		;;
	v)      (( ++VerboseLevel ))
		;;
	x)      NoHeader=yes
		;;
	h)      print -- "$Usage"
		exit 0
		;;
	\?)     exit 1
		;;
    esac
done

# Shift away all option arguments.
shift $(( OPTIND - 1 ))

(( $# >= 1 )) || { print -u2 -- "Missing action argument."; exit 1; }

if [[ ${s_opt+_} ]]; then
	if [[ $s_opt != +([[:digit:].]):+([[:digit:].]) ]]; then
		print -u2 -- "Invalid sleep argument ($s_opt)."
		exit 1
	fi

	SleepInit=${.sh.match[1]}
	SleepLoop=${.sh.match[2]}

	if ! is_dec_fraction "$SleepInit" || ! is_dec_fraction "$SleepLoop"; then
		print -u2 -- "Invalid sleep argument ($s_opt)."
		exit 1
	fi
fi

Action=$1
shift

# We set pipefail so that we can determine if anything in the entire pipeline
# failed.
set -o pipefail
set -o nounset
set -o errexit

trap "cleanup" HUP INT QUIT TERM

typeset retval=0

case $Action in
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
		    retval=$?
		    ;;
  start)            check_root
		    startdsrs
		    retval=$?
		    ;;
  stop)             check_root
		    stopdsrs
		    retval=$?
		    ;;
  *)                print -u2 -- "Invalid action provided ($Action)."
		    retval=1
		    ;;
esac

exit $retval
