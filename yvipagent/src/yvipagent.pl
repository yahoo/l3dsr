#! /usr/local/bin/perl -Tw
#
# Copyright (c) 2009,2010,2011,2012 Yahoo! Inc.
#
# Originally written by Jan Schaumann <jschauma@yahoo-inc.com> in September
# 2009.
#
# This program configures a host for participation in one or more
# VIPs.  It does this by parsing the VIP configuration files found in the
# directory specified via the -d flag and installing the necessary firewall
# rules, loopback aliases, kernel modules etc.
#
#
# Redistribution and use of this software in source and binary forms, with
# or without modification, are permitted provided that the following
# conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# * Neither the name of Yahoo! Inc. nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission of Yahoo! Inc.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use File::Basename;
use Getopt::Long;
Getopt::Long::Configure("bundling");
use Socket;
use Socket6;

###
### Constants
###

use constant TRUE => 1;
use constant FALSE => 0;

use constant EXIT_FAILURE => 1;
use constant EXIT_SUCCESS => 0;

use constant DEFAULT_DIR => "/usr/local/etc/yvip/vips";

###
### Globals
###

$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

my %OPTS;
my $PROGNAME = basename($0);

my %SUPPORTED_ACTIONS = ( "check" => 1,
			  "start" => 1,
			  "stop" => 1,
			);

my %SUPPORTED_OS = ( "freebsd" => 1,
			"linux" => 1,
		);

my %SUPPORTED_TYPES = ( "l3-dsr" => 1 );

my %OS_DETAILS = (
			"freebsd" => {
					"kernel_modules" => "dscp_rewrite",
					"kernel_module_test" => "/sbin/kldstat -q -m <mod>",
					"kernel_module_load" => "/sbin/kldload <mod>",
					"loopback_start" => "/sbin/ifconfig lo0 <vip>",
					"loopback_stop" => "/sbin/ifconfig lo0 <vip> delete",
					"firewall_rule" => "net.inet.ip.dscp_rewrite.<dscp>=<vip>",
					"firewall_config_check" => "/sbin/sysctl net.inet.ip.dscp_rewrite.<dscp>",
					"firewall_config_start" => "/sbin/sysctl <rule>",
					"firewall_config_stop" => "/sbin/sysctl <rule>",
				},
			"linux" => {
					"kernel_modules" => "",
					"kernel_module_test" => "/bin/grep -q ^<mod> /proc/modules",
					"kernel_module_load" => "/sbin/modprobe <mod>",
					"loopback_start" => "/sbin/ifconfig lo",
					"loopback_stop" => "/sbin/ifconfig lo:<alias> down",
					"firewall_rule" => "-m dscp --dscp <dscp> -j DADDR --set-daddr=<vip>",
					"firewall_config_check" => "/sbin/iptables -t mangle -L -n",
					"firewall_config_start" => "/sbin/iptables -t mangle -A PREROUTING <rule>",
					"firewall_config_stop" => "/sbin/iptables -t mangle -D PREROUTING <rule>",
				},
		);

###
### Subroutines
###

# function : configureFirewall
# purpose  : configure any firewall rules applicable for this VIP
# inputs   : a vip ip, a dscp bit
# returns  : nothing, may die on error

sub configureFirewall($$) {
	my ($vip, $dscp) = @_;

	if ($OPTS{'ACTION'} eq "start") {
		configureFirewallStart($OPTS{'OS'}, $vip, $dscp);
	} elsif ($OPTS{'ACTION'} eq "stop") {
		configureFirewallStop($OPTS{'OS'});
	}
}


# function : configureFirewallStart
# purpose  : configure any firewall rules applicable for this VIP
#            and start them
# inputs   : os type, a vip ip, a dscp bit
# returns  : nothing, may die on error

sub configureFirewallStart($$$) {
	my ($os, $vip, $dscp) = @_;

	my ($check, $cmd, $exists, $rule);

	verbose("Adding firewall rules...", 3);

	$check = $OS_DETAILS{$os}{'firewall_config_check'};
	$check =~ s/<dscp>/$dscp/g;
	$exists = `$check`;
	if ($exists =~ m/$vip\n/) {
		error("This host is already configured for $vip", EXIT_FAILURE);
		# NOTREACHED
	}

	$cmd =  $OS_DETAILS{$os}{'firewall_config_start'};
	$rule =  $OS_DETAILS{$os}{'firewall_rule'};
	$rule =~ s/<dscp>/$dscp/g;
	$rule =~ s/<vip>/$vip/g;
	$cmd =~ s/<rule>/$rule/g;
	runCommandOrDie($cmd);
}

# function : configureFirewallStop
# purpose  : unconfigure all L3-DSR firewall rules
# inputs   : os type
# returns  : nothing, may die on error

sub configureFirewallStop($) {
	my ($os) = @_;

	verbose("Removing firewall rules...", 3);

	if ($OPTS{'OS'} eq "freebsd") {
		configureFirewallStopFreeBSD();
	} elsif ($OPTS{'OS'} eq "linux") {
		configureFirewallStopLinux();
	}
}

# function : configureFirewallStopFreeBSD
# purpose  : unconfigure all L3-DSR firewall rules on FreeBSD
# inputs   : none
# returns  : nothing; dies on error

sub configureFirewallStopFreeBSD() {

	my ($cmd, $rule);
	$cmd =  $OS_DETAILS{'freebsd'}{'firewall_config_stop'};
	$cmd =~ s/<rule>//g;
	# explicitly set all values to 0.0.0.0...
	for my $dscp (1..63) {
		$rule = $OS_DETAILS{'freebsd'}{'firewall_rule'};
		$rule =~ s/<dscp>/$dscp/g;
		$rule =~ s/<vip>/0.0.0.0/g;
		$cmd .= " $rule";
	}
	# ... then explicitly disable dscp_rewrite
	$rule = $OS_DETAILS{'freebsd'}{'firewall_rule'};
	$rule =~ s/<dscp.*/enabled=0/;
	$cmd .= " $rule";
	$cmd .= " >/dev/null";
	runCommandOrDie($cmd);
}

# function : configureFirewallStopLinux
# purpose  : unconfigure all L3-DSR firewall rules on Linux
# inputs   : none
# returns  : nothing; dies on error

sub configureFirewallStopLinux() {

	my (@goners, $table);

	my $cmd =  $OS_DETAILS{'linux'}{'firewall_config_check'};
	$cmd =~ s/ PREROUTING//;
	$cmd .= " --line-numbers";

	$table = 0;
	foreach my $line (split(/\n/, `$cmd`)) {
		if ($line =~ m/^Chain PREROUTING/) {
			$table = 1;
		} elsif ($line =~ m/^Chain /) {
			$table = 0;
		}

		if ($table) {
			if ($line =~ m/^(\d+)\s+DADDR\s+.*\s+DSCP match\s+/) {
				push(@goners, $1);
			}
		}
	}

	if (scalar(@goners)) {
		foreach my $rule (reverse(@goners)) {
			$cmd = $OS_DETAILS{'linux'}{'firewall_config_stop'};
			$cmd =~ s/<rule>/$rule/g;
			runCommandOrDie($cmd);
		}
	}
}


# function : configureLoopback
# purpose  : configure the loopback device for the given VIP
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopback($$) {
	my ($ip, $af) = @_;

	verbose(sprintf("%s loopback for $ip...",
				$OPTS{'ACTION'} eq "start" ? "Configuring" : "Unconfiguring"), 3);
	if ($OPTS{'OS'} eq "freebsd") {
		configureLoopbackFreeBSD($ip, $af);
	} elsif ($OPTS{'OS'} eq "linux") {
		configureLoopbackLinux($ip, $af);
	}
}


# function : configureLoopbackFreeBSD
# purpose  : configure the loopback device for the given VIP
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackFreeBSD($$) {
	my ($ip, $af) = @_;

	if ($OPTS{'ACTION'} eq "start") {
		configureLoopbackFreeBSDStart($ip, $af);
	} elsif ($OPTS{'ACTION'} eq "stop") {
		configureLoopbackFreeBSDStop($ip, $af);
	}
}


# function : configureLoopbackFreeBSDStart
# purpose  : configure the loopback device for the given VIP and enable it
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackFreeBSDStart($$) {
	my ($ip, $af) = @_;

	my $vip;

	if ($af eq "AF_INET") {
		$vip = "$ip netmask 0xffffffff alias";
	} elsif ($af eq "AF_INET6") {
		$vip = "inet6 $ip/128\n";
	}

	my $cmd = $OS_DETAILS{'freebsd'}{'loopback_start'};
	$cmd =~ s/<vip>/$vip/g;
	runCommandOrDie($cmd);
}


# function : configureLoopbackFreeBSDStop
# purpose  : unconfigure the loopback device for the given VIP and disable it
# inputs   : an IP address, address family
# returns  : nothing, silently ignores errors

sub configureLoopbackFreeBSDStop($$) {
	my ($ip, $af) = @_;

	my $cmd = $OS_DETAILS{'freebsd'}{'loopback_stop'};
	if ($af eq "AF_INET") {
		$cmd =~ s/<vip>/$ip/g;
	} elsif ($af eq "AF_INET6") {
		$cmd =~ s/<vip>/inet6 $ip/g;
	}

	runCommand($cmd);
}


# function : configureLoopbackLinux
# purpose  : configure the loopback device for the given VIP
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackLinux($$) {
	my ($ip, $af) = @_;

	if ($OPTS{'ACTION'} eq "start") {
		configureLoopbackLinuxStart($ip, $af);
	} elsif ($OPTS{'ACTION'} eq "stop") {
		configureLoopbackLinuxStop($ip, $af);
	}
}


# function : configureLoopbackLinuxStart
# purpose  : configure the loopback device for the given VIP and enable it
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackLinuxStart($$) {
	my ($ip, $af) = @_;

	my $cmd = $OS_DETAILS{'linux'}{'loopback_start'};
	my $loopback_alias = getLoopbackAlias();

	$cmd .= ":$loopback_alias";

	verbose("Configuring lo:$loopback_alias...", 3);
	if ($af eq "AF_INET") {
		$cmd .= " $ip netmask 255.255.255.255";
	} elsif ($af eq "AF_INET6") {
		$cmd = " $ip/128";
	}
	runCommandOrDie($cmd);
}

# function : configureLoopbackLinuxStop
# purpose  : unconfigure the loopback device for the given VIP and disable it
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackLinuxStop($$) {
	my ($ip, $af) = @_;

	verbose("Unconfiguring loopback device...", 3);
	my $loopback_alias = -1;
	my $cmd = "/sbin/ifconfig -a";
	foreach my $line (split(/\n/, `$cmd`)) {
		if ($line =~ m/^lo:(\d+)/) {
			$loopback_alias = $1;
			next;
		}

		if ($loopback_alias >= 0) {
			if ($line =~ m/inet addr:$ip\s/) {
				last;
			}
		}
	}

	if ($loopback_alias < 0) {
		# No loopback alias found.
		return;
	}

	$cmd = $OS_DETAILS{'linux'}{'loopback_stop'};
	$cmd =~ s/<alias>/$loopback_alias/g;
	runCommandOrDie($cmd);
}

# function : configureVip
# purpose  : configure a given Vip
# inputs   : a "vip configuration object" (ie hash ref)
# returns  : nothing, may abort on error

sub configureVip($) {
	my ($hr) = @_;
	my %vip = %{$hr};

	verbose(sprintf("%s host for VIP %s (DSCP: %s)...",
				$OPTS{'ACTION'} eq "start" ? "Configuring" : "Unconfiguring",
				$vip{'ip'},
				$vip{'dscp'}), 2);

	# order matters :-/
	if ($OPTS{'ACTION'} eq "start") {
		handleKernelModules();
		configureFirewall($vip{'ip'}, $vip{'dscp'});
	} else {
		configureFirewall($vip{'ip'}, $vip{'dscp'});
		handleKernelModules();
	}

	configureLoopback($vip{'ip'}, $vip{'af'});
}


# function : error
# purpose  : print given message to STDERR, then exit with optionally
#            given exit code
# input    : message, exit code

sub error($;$) {
	my ($msg, $err) = @_;

	print STDERR "$PROGNAME: $msg\n";

        if ($err) {
                exit($err);
                # NOTREACHED
        }
}


# function : getLoopbackAlias
# purpose  : determine an available loopback alias, such as lo:0
#            this is a linux specific function; it invokes "ifconfig -a"
#            and parses the output
# inputs   : none
# returns  : an integer or dies on error

sub getLoopbackAlias() {
	my $l = 0;
	my $highest = 0;

	my $cmd = "/sbin/ifconfig -a";
	foreach my $line (split(/\n/, `$cmd`)) {
		if ($line =~ m/^lo:(\d+)/) {
			$highest = ($1 > $highest) ? $1 : $highest;
		}
	}

	$l = $highest + 1;
	return $l;
}


# function : handleKernelModules
# purpose  : load any required kernel modules
# inputs   : none
# returns  : nothing, may die on error

sub handleKernelModules() {
	my $os = $OPTS{'OS'};

	if ($OPTS{'ACTION'} ne "start") {
		# Nothing to do, we don't try to disable any modules.
		return;
	}

	foreach my $mod (split(/ /, $OS_DETAILS{$os}{'kernel_modules'})) {
		my $testcmd = $OS_DETAILS{$os}{'kernel_module_test'};
		$testcmd =~ s/<mod>/$mod/;

		if (runCommand($testcmd) != 0) {
			my $runcmd = $OS_DETAILS{$os}{'kernel_module_load'};
			$runcmd =~ s/<mod>/$mod/;
			verbose("Loading/verifying kernel module $mod...", 4);
			runCommandOrDie($runcmd);
		}
	}
}


# function : init
# purpose  : initialize variables, parse command line options;
# inputs   : none
# returns  : void, may exit under certain conditions

sub init() {
	my ($ok, %rc_opts);

	$ok = GetOptions("directory|d=s" => sub { delete $OPTS{'f'}; $OPTS{'d'} = $_[1]; },
			"file|f=s" => sub { delete $OPTS{'d'}; $OPTS{'f'} = $_[1]; },
			"help|h" => \$OPTS{'h'},
			"verbose|v+" => sub { $OPTS{'v'}++; },
			);

	if ($OPTS{'h'} || !$ok) {
		usage($ok);
		exit(!$ok);
		# NOTREACHED
	}

	if ((scalar(@ARGV) != 1) || ($ARGV[0] !~ m/^(check|start|stop)$/)) {
		error("You need to specify exactly one of 'check', 'start' or 'stop'.",
				EXIT_FAILURE);
		# NOTREACHED
	}

	$OPTS{'ACTION'} = $ARGV[0];
	$OPTS{'OS'} = $^O;

	if (!$OPTS{'d'} && !$OPTS{'f'}) {
		$OPTS{'d'} = DEFAULT_DIR;
	}
}

# function : parseFile
# purpose  : parse a single config file and return a hash "vip config
#            object" representing this vip
# inputs   : a file name
# returns  : a hash representing a single "vip config object"

sub parseFile($) {
	my ($file) = @_;
	my ($fh, %vip, $lineno);

	verbose("Parsing $file...", 2);
	$lineno = 0;

	open($fh, "<", $file) || die("Unable to open $file: $!\n");
	while (my $line = <$fh>) {
		$lineno++;
		$line =~ s/#.*//;
		$line =~ s/^\s*//;
		$line =~ s/\s+$//;
		chomp($line);

		next unless $line;

		$line = lc($line);
		if ($line =~ m/^(\S+)=(\S+)$/) {
			$vip{$1} = $2;
		} else {
			error("Syntax error in $file (line $lineno).", EXIT_FAILURE);
			# NOTREACHED
		}
	}
	close($fh);

	if (!$vip{'ip'}) {
		error("No 'ip' found in $file - not a yvip config file?", EXIT_FAILURE);
		# NOTREACHED
	}

	if (inet_pton(AF_INET, $vip{'ip'})) {
		$vip{'af'} = "AF_INET";
	} elsif (inet_pton(AF_INET6, $vip{'ip'})) {
		$vip{'af'} = "AF_INET6";
	} else {
		error("Invalid IP " . $vip{'ip'} . " in $file.", EXIT_FAILURE);
		# NOTREACHED
	}

	# When stopping, we want to stop everything even if there are errors.
	if ($OPTS{'ACTION'} ne "stop") {
		verifyVip(\%vip, $file);
	}

	return \%vip;
}


# function : parseInput
# purpose  : parse all given vip config files and return a hash of "vip
#            config" 'objects' by IP.
#
#            A "vip config" object is a hash of key=value pairs found in
#            the vip configuration.
# inputs   : none, operates on the file found in OPTS{'f'} and all files
#            found under OPTS{'d'}
# returns  : a hash reference containing "vip config" objects

sub parseInput() {
	my (@files, %vips);

	verbose("Parsing all input...");

	if ($OPTS{'d'}) {
		my $dh;
		opendir($dh, $OPTS{'d'}) || die("Unable to open directory " . $OPTS{'d'} . ": $!\n");
		push(@files, grep { -f "$OPTS{'d'}/$_" } readdir($dh));
		closedir($dh);

		@files = map { $OPTS{'d'} . '/' . $_ } @files;
		$OPTS{'ALL'} = 1;
	}

	if ($OPTS{'f'}) {
		push(@files, $OPTS{'f'});
	}

	foreach my $f (@files) {
		my $vr = parseFile($f);
		my %vip = %{$vr};
		my $ip = $vip{'ip'};
		# When stopping, we want to stop everything even if there are
		# errors.
		if ($OPTS{'ACTION'} ne "stop") {
			verifyVipAgainstAllVips(\%vip, \%vips);
		}
		$vips{$ip} = \%vip;
	}

	return \%vips;
}


# function : runCommand
# purpose  : run the given command via 'system'
# inputs   : a full command string
# returns  : exit status of the command

sub runCommand($) {
	my ($cmdline) = @_;

	verbose("Running '$cmdline'...", 5);
	my $rval = (system($cmdline) >> 8);
	return $rval;
}

# function : runCommandOrDie
# purpose  : run the given command and die if it returns unsuccessfully
# inputs   : a full command string
# returns  : nothing, may die on failure

sub runCommandOrDie($) {
	my ($cmd) = @_;

	my $rval = runCommand($cmd);
	if ($rval != 0) {
		error("Unable to run '$cmd' (returned $rval).", EXIT_FAILURE);
		# NOTREACHED
	}
}



# function : usage
# purpose  : print usage statement
# inputs   : an integer; if 0, print output to STDERR, else to STDOUT
# returns  : void

sub usage($) {
	my ($err) = @_;

	my $FH = $err ? \*STDERR : \*STDOUT;

	print $FH <<EOH
Usage: $PROGNAME [-hv] [-d dir] [-f file] start | stop
       -d dir   specify directory to look for vip configs in
       -f file  read a single vip config from this file
       -h       print a usage statement and exit
       -v       be verbose
EOH
}


# function : verbose
# purpose  : print a message if given verbosity is set
# input    : a string and a verbosity level

sub verbose($;$) {
	my ($msg, $level) = @_;
	my $char = "=";

	return unless $OPTS{'v'};

	$char .= "=" x ($level ? ($level - 1) : 0 );

	if (!$level || ($level <= $OPTS{'v'})) {
		print STDERR "$char> $msg\n";
	}
}


# function : verifyVipAgainstAllVips
# purpose  : check all the given vip does not conflict with any existing vips
#            at this point, this is pretty much restricted to checking that
#            we have no "IP<->dscp" pair conflicts
# inputs   : a hashref of all VIPs
# returns  : nothing, dies if conflicts are found

sub verifyVipAgainstAllVips($$) {
	my ($avr, $allvr) = @_;
	my %aVip = %{$avr};
	my %allVips = %{$allvr};

	verbose("Verifying all VIP configurations...");

	foreach my $vip (keys(%allVips)) {
		my $existing_dscp = $allVips{$vip}{'dscp'};
		my $new_dscp = $aVip{'dscp'};
		if (($aVip{'ip'} eq "$vip") && ($aVip{'dscp'} != $existing_dscp)) {
			error("$vip (dscp: $existing_dscp) conflicts with $vip (dscp: $new_dscp).",
					EXIT_FAILURE);
			# NOTREACHED
		}
	}
}


# function : verifyOptions
# purpose  : verify that any options we lateron if-else on have valid values
# inputs   : none, operates on %OPTS
# returns  : nothing, may die on error

sub verifyOptions() {
	if (!$OPTS{'ACTION'} || (!defined($SUPPORTED_ACTIONS{$OPTS{'ACTION'}}))) {
		error("ACTION is unset or invalid.", EXIT_FAILURE);
		# NOTREACHED
	}

	if (!$OPTS{'OS'} || (!defined($SUPPORTED_OS{$OPTS{'OS'}}))) {
		error("OS is unset or invalid.", EXIT_FAILURE);
		# NOTREACHED
	}
}


# function : verifyVip
# purpose  : verify that a given vip configuration is valid
# inputs   : a vip config opbject (ie hash ref), a config file
# returns  : nothing, may error on error

sub verifyVip($$) {
	my ($vr, $file) = @_;
	my %vip = %{$vr};

	foreach my $key ("ip", "type") {
		if (!$vip{$key}) {
			error("Invalid VIP config -- '$key' missing from $file.",
				EXIT_FAILURE);
			# NOTREACHED
		}
	}

	if (!$SUPPORTED_TYPES{$vip{'type'}}) {
		error("Invalid VIP config -- type '" . $vip{'type'} .
			"' not supported.", EXIT_FAILURE);
		# NOTREACHED
	}

	if (($vip{'type'} eq "l3-dsr") && !$vip{'dscp'}) {
		error("Invalid VIP config -- l3-dsr type is missing dscp key.",
			EXIT_FAILURE);
		# NOTREACHED
	}
}


###
### Main
###

init();
verifyOptions();

my %vipConfigs = %{parseInput()};

if ($OPTS{'ACTION'} eq "check") {
	print "Syntax ok.\n";
	exit(EXIT_SUCCESS);
	# NOTREACHED
}

verbose("Configuring host for all vips (" . scalar(keys(%vipConfigs)) . " total)...");
foreach my $vip (keys(%vipConfigs)) {
	configureVip($vipConfigs{$vip});
}

my $act = $OPTS{'ACTION'};
if ($act eq "stop") {
	$act .= "p";
}
printf "All vips ${act}ed.\n";
exit(EXIT_SUCCESS);
