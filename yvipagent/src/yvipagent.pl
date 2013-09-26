#! /usr/local/bin/perl -Tw
#
# Copyright (c) 2009,2010,2011,2012,2013 Yahoo! Inc.
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
#

use strict;
use File::Basename;
use Getopt::Long;
Getopt::Long::Configure("bundling");
use Socket;

# Import the Socket6 library for Perl versions < 5.12
if ( !defined(&Socket::inet_ntop) ) {
    eval "use Socket6;";    # For Perl versions < 5.12
    die $@ if $@;
}
else {
    Socket->import(qw( inet_ntop inet_pton AF_INET6 AF_INET ));
}

###
### Constants
###

use constant TRUE  => 1;
use constant FALSE => 0;

use constant EXIT_FAILURE => 1;
use constant EXIT_SUCCESS => 0;

use constant DEFAULT_DIR => "/usr/local/etc/yvip/vips";

###
### Globals
###

$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin';
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

my %OPTS;
my $PROGNAME = basename($0);

my %SUPPORTED_ACTIONS = (
    "check" => 1,
    "start" => 1,
    "stop"  => 1,
);

my %SUPPORTED_OS = (
    "freebsd" => 1,
    "linux"   => 1,
);

my %SUPPORTED_TYPES = (
    "l3-dsr" => 1,
    "dsr"    => 1
);

my %OS_DETAILS = (
    "freebsd" => {

        # FreeBSD-specific implementation details
        "kernel_modules"     => "dscp_rewrite",
        "kernel_module_test" => "/sbin/kldstat -q -m <mod>",
        "kernel_module_load" => "/sbin/kldload <mod>",
        "loopback_start"     => "/sbin/ifconfig lo0 <vip>",
        "loopback_stop"      => "/sbin/ifconfig lo0 <vip> delete",
        "firewall_rule"      => "net.inet.ip.dscp_rewrite.<dscp>=<vip>",
        "firewall_config_check" =>
          "/sbin/sysctl net.inet.ip.dscp_rewrite.<dscp>",
        "firewall_config_start" =>
          "/sbin/sysctl net.inet.ip.dscp_rewrite.enabled=1 <rule>",
        "firewall_config_stop" => "/sbin/sysctl <rule>",
    },
    "linux" => {

        # Linux-specific implementation details
        "kernel_modules"     => "",
        "kernel_module_test" => "/bin/grep -q ^<mod> /proc/modules",
        "kernel_module_load" => "/sbin/modprobe <mod>",
        "firewall_rule" => "-m dscp --dscp <dscp> -j DADDR --set-daddr=<vip>",

        # IPv4-specific commands
        "loopback_start"        => "/sbin/ifconfig lo",
        "loopback_stop"         => "/sbin/ifconfig lo:<alias> down",
        "firewall_config_check" => "/sbin/iptables -t mangle -L -n",
        "firewall_config_start" =>
          "/sbin/iptables -t mangle -A PREROUTING <rule>",
        "firewall_config_stop" =>
          "/sbin/iptables -t mangle -D PREROUTING <rule>",

        # IPv6-specific commands
        "loopback6_start"        => "/sbin/ifconfig lo inet6 add",
        "loopback6_stop"         => "/sbin/ifconfig lo inet6 del",
        "firewall6_config_check" => "/sbin/ip6tables -t mangle -L -n",
        "firewall6_config_start" =>
          "/sbin/ip6tables -t mangle -A PREROUTING <rule>",
        "firewall6_config_stop" =>
          "/sbin/ip6tables -t mangle -D PREROUTING <rule>",
    },
);

###
### Subroutines
###

# function : configureFirewall
# purpose  : configure any firewall rules applicable for this VIP
# inputs   : a vip ip, a dscp bit
# returns  : nothing, may die on error

sub configureFirewall($$$) {
    my ( $vip, $dscp, $af ) = @_;

    if ( $OPTS{'ACTION'} eq "start" ) {
        configureFirewallStart( $OPTS{'OS'}, $vip, $dscp, $af );
    }
    elsif ( $OPTS{'ACTION'} eq "stop" ) {
        configureFirewallStop( $OPTS{'OS'}, $af );
    }
}

# function : configureFirewallStart
# purpose  : configure any firewall rules applicable for this VIP
#            and start them
# inputs   : os type, a vip ip, a dscp bit
# returns  : nothing, may die on error

sub configureFirewallStart($$$$) {
    my ( $os, $vip, $dscp, $af ) = @_;

    my ( $check, $cmd, $exists, $rule );

    verbose( "Adding firewall rules...", 3 );

    # We currently do not have IPv6 support for FreeBSD.
    if ( $af eq "AF_INET" || $os eq 'freebsd' ) {
        $check = $OS_DETAILS{$os}{'firewall_config_check'};
    }
    elsif ( $af eq "AF_INET6" ) {
        $check = $OS_DETAILS{$os}{'firewall6_config_check'};
    }

    $check =~ s/<dscp>/$dscp/g;
    $exists = `$check`;
    if ( $exists =~ m/$vip\n/ ) {
        error( "This host is already configured for $vip", EXIT_FAILURE );
        
        return

        # NOTREACHED
    }

    # We currently do not have IPv6 support for FreeBSD.
    if ( $af eq "AF_INET" || $os eq 'freebsd' ) {
        $cmd = $OS_DETAILS{$os}{'firewall_config_start'};
    }
    elsif ( $af eq "AF_INET6" ) {
        $cmd = $OS_DETAILS{$os}{'firewall6_config_start'};
    }

    $rule = $OS_DETAILS{$os}{'firewall_rule'};
    $rule =~ s/<dscp>/$dscp/g;
    $rule =~ s/<vip>/$vip/g;
    $cmd  =~ s/<rule>/$rule/g;

    runCommandOrDie($cmd);
}

# function : configureFirewallStop
# purpose  : unconfigure all L3-DSR firewall rules
# inputs   : os type
# returns  : nothing, may die on error

sub configureFirewallStop($$) {
    my ( $os, $af ) = @_;

    verbose( "Removing firewall rules...", 3 );

    if ( $OPTS{'OS'} eq "freebsd" ) {
        configureFirewallStopFreeBSD();
    }
    elsif ( $OPTS{'OS'} eq "linux" ) {
        configureFirewallStopLinux($af);
    }
}

# function : configureFirewallStopFreeBSD
# purpose  : unconfigure all L3-DSR firewall rules on FreeBSD
# inputs   : none
# returns  : nothing; dies on error

sub configureFirewallStopFreeBSD() {

    my ( $cmd, $rule );
    $cmd = $OS_DETAILS{'freebsd'}{'firewall_config_stop'};
    $cmd =~ s/<rule>//g;

    # explicitly set all values to 0.0.0.0...
    for my $dscp ( 1 .. 63 ) {
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

sub configureFirewallStopLinux($) {

    my $af = shift;
    my ( @goners, $table );
    my $cmd;

    if ( $af eq "AF_INET" ) {
        $cmd = $OS_DETAILS{'linux'}{'firewall_config_check'};
    }
    elsif ( $af eq "AF_INET6" ) {
        $cmd = $OS_DETAILS{'linux'}{'firewall6_config_check'};
    }
    $cmd =~ s/ PREROUTING//;
    $cmd .= " --line-numbers";

    $table = 0;
    foreach my $line ( split( /\n/, `$cmd` ) ) {
        if ( $line =~ m/^Chain PREROUTING/ ) {
            $table = 1;
        }
        elsif ( $line =~ m/^Chain / ) {
            $table = 0;
        }

        if ($table) {
            if ( $line =~ m/^(\d+)\s+DADDR\s+.*\s+DSCP match\s+/ ) {
                push( @goners, $1 );
            }
        }
    }

    if ( scalar(@goners) ) {
        foreach my $rule ( reverse(@goners) ) {
            if ( $af eq "AF_INET" ) {
                $cmd = $OS_DETAILS{'linux'}{'firewall_config_stop'};
            }
            elsif ( $af eq "AF_INET6" ) {
                $cmd = $OS_DETAILS{'linux'}{'firewall6_config_stop'};
            }
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
    my ( $ip, $af ) = @_;

    verbose(
        sprintf( "%s loopback for $ip...",
            $OPTS{'ACTION'} eq "start" ? "Configuring" : "Unconfiguring" ),
        3
    );
    if ( $OPTS{'OS'} eq "freebsd" ) {
        configureLoopbackFreeBSD( $ip, $af );
    }
    elsif ( $OPTS{'OS'} eq "linux" ) {
        configureLoopbackLinux( $ip, $af );
    }
}

# function : configureLoopbackFreeBSD
# purpose  : configure the loopback device for the given VIP
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackFreeBSD($$) {
    my ( $ip, $af ) = @_;

    if ( $OPTS{'ACTION'} eq "start" ) {
        configureLoopbackFreeBSDStart( $ip, $af );
    }
    elsif ( $OPTS{'ACTION'} eq "stop" ) {
        configureLoopbackFreeBSDStop( $ip, $af );
    }
}

# function : configureLoopbackFreeBSDStart
# purpose  : configure the loopback device for the given VIP and enable it
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackFreeBSDStart($$) {
    my ( $ip, $af ) = @_;
    my $vip;

    # Build up the command
    if ( $af eq "AF_INET" ) {
        $vip = "$ip netmask 0xffffffff alias";
    }
    elsif ( $af eq "AF_INET6" ) {
        $vip = "inet6 $ip/128\n";
    }
    
    # Run the command and configure the loopback interface
    my $cmd = $OS_DETAILS{'freebsd'}{'loopback_start'};
    $cmd =~ s/<vip>/$vip/g;
    runCommandOrDie($cmd);
}

# function : configureLoopbackFreeBSDStop
# purpose  : unconfigure the loopback device for the given VIP and disable it
# inputs   : an IP address, address family
# returns  : nothing, silently ignores errors

sub configureLoopbackFreeBSDStop($$) {
    my ( $ip, $af ) = @_;

    my $cmd = $OS_DETAILS{'freebsd'}{'loopback_stop'};
    if ( $af eq "AF_INET" ) {
        $cmd =~ s/<vip>/$ip/g;
    }
    elsif ( $af eq "AF_INET6" ) {
        $cmd =~ s/<vip>/inet6 $ip/g;
    }

    runCommand($cmd);
}

# function : configureLoopbackLinux
# purpose  : configure the loopback device for the given VIP
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackLinux($$) {
    my ( $ip, $af ) = @_;

    if ( $OPTS{'ACTION'} eq "start" ) {
        configureLoopbackLinuxStart( $ip, $af );
    }
    elsif ( $OPTS{'ACTION'} eq "stop" ) {
        configureLoopbackLinuxStop( $ip, $af );
    }
}

# function : configureLoopbackLinuxStart
# purpose  : configure the loopback device for the given VIP and enable it
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackLinuxStart($$) {
    my ( $ip, $af ) = @_;

    my $cmd;
    my $loopback_alias;

    if ( $af eq "AF_INET" ) {
        $loopback_alias = getLoopbackAlias();
        $cmd            = $OS_DETAILS{'linux'}{'loopback_start'};
        $cmd .= ":$loopback_alias";
        verbose( "Configuring lo:$loopback_alias...", 3 );
        $cmd .= " $ip netmask 255.255.255.255";
    }
    elsif ( $af eq "AF_INET6" ) {
        $cmd = $OS_DETAILS{'linux'}{'loopback6_start'};
        verbose( "Configuring lo...", 3 );
        $cmd .= " $ip/128";
    }

    runCommandOrDie($cmd);
}

# function : configureLoopbackLinuxStop
# purpose  : unconfigure the loopback device for the given VIP and disable it
# inputs   : an IP address, address family
# returns  : nothing, may die on error

sub configureLoopbackLinuxStop($$) {
    my ( $ip, $af ) = @_;
    my $cmd;
    my $loopback_alias = -1;

    verbose( "Unconfiguring loopback device...", 3 );

    if ( $af eq "AF_INET" ) {
        $cmd = "/sbin/ifconfig -a";
        foreach my $line ( split( /\n/, `$cmd` ) ) {
            if ( $line =~ m/^lo:(\d+)/ ) {
                $loopback_alias = $1;
                next;
            }

            if ( $loopback_alias >= 0 ) {
                if ( $line =~ m/inet addr:$ip\s/ ) {
                    last;
                }
            }
        }

        if ( $loopback_alias < 0 ) {

            # No loopback alias found.
            return;
        }

        $cmd = $OS_DETAILS{'linux'}{'loopback_stop'};
        $cmd =~ s/<alias>/$loopback_alias/g;
    }
    elsif ( $af eq "AF_INET6" ) {
        $cmd = $OS_DETAILS{'linux'}{'loopback6_stop'};
        $cmd .= " $ip/128";
    }

    runCommandOrDie($cmd);
}

# function : configureVip
# purpose  : configure a given Vip
# inputs   : a "vip configuration object" (ie hash ref)
# returns  : nothing, may abort on error

sub configureVip($) {
    my ($hr) = @_;
    my %vip = %{$hr};
    verbose(
        sprintf(
            "%s host for VIP %s (DSCP: %s)...",
            $OPTS{'ACTION'} eq "start" ? "Configuring" : "Unconfiguring",
            $vip{'ip'},
            $vip{'type'} eq "l3-dsr" ? $vip{'dscp'} : "None"
        ),
        2
    );

    if ( $vip{'type'} eq "l3-dsr" ) {

        # order matters :-/
        if ( $OPTS{'ACTION'} eq "start" ) {
            handleKernelModules();
            configureFirewall( $vip{'ip'}, $vip{'dscp'}, $vip{'af'} );
        }
        else {
            configureFirewall( $vip{'ip'}, $vip{'dscp'}, $vip{'af'} );
            handleKernelModules();
        }
    }

    configureLoopback( $vip{'ip'}, $vip{'af'} );
}

# function : error
# purpose  : print given message to STDERR, then exit with optionally
#            given exit code
# input    : message, exit code

sub error($;$) {
    my ( $msg, $err ) = @_;

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
    my $l       = 0;
    my $highest = 0;

    my $cmd = "/sbin/ifconfig -a";
    foreach my $line ( split( /\n/, `$cmd` ) ) {
        if ( $line =~ m/^lo:(\d+)/ ) {
            $highest = ( $1 > $highest ) ? $1 : $highest;
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

    if ( $OPTS{'ACTION'} ne "start" ) {

        # Nothing to do, we don't try to disable any modules.
        return;
    }

    foreach my $mod ( split( / /, $OS_DETAILS{$os}{'kernel_modules'} ) ) {
        my $testcmd = $OS_DETAILS{$os}{'kernel_module_test'};
        $testcmd =~ s/<mod>/$mod/;

        if ( runCommand($testcmd) != 0 ) {
            my $runcmd = $OS_DETAILS{$os}{'kernel_module_load'};
            $runcmd =~ s/<mod>/$mod/;
            verbose( "Loading/verifying kernel module $mod...", 4 );
            runCommandOrDie($runcmd);
        }
    }
}

# function : init
# purpose  : initialize variables, parse command line options;
# inputs   : none
# returns  : void, may exit under certain conditions

sub init() {
    my ( $ok, %rc_opts );

    $ok = GetOptions(
        "directory|d=s" => sub { delete $OPTS{'f'}; $OPTS{'d'} = $_[1]; },
        "file|f=s"      => sub { delete $OPTS{'d'}; $OPTS{'f'} = $_[1]; },
        "help|h"     => \$OPTS{'h'},
        "verbose|v+" => sub { $OPTS{'v'}++; },
    );

    if ( $OPTS{'h'} || !$ok ) {
        usage($ok);
        exit( !$ok );

        # NOTREACHED
    }

    if ( ( scalar(@ARGV) != 1 ) || ( $ARGV[0] !~ m/^(check|start|stop)$/ ) ) {
        error( "You need to specify exactly one of 'check', 'start' or 'stop'.",
            EXIT_FAILURE );

        # NOTREACHED
    }

    $OPTS{'ACTION'} = $ARGV[0];
    $OPTS{'OS'}     = $^O;

    if ( !$OPTS{'d'} && !$OPTS{'f'} ) {
        $OPTS{'d'} = DEFAULT_DIR;
    }
}

# function : parseFile
# purpose  : parse a single config file and return a hash "VIP config
#            object" representing all found VIPs
# inputs   : a file name
# returns  : a hash representing all VIPs

sub parseFile($) {
    my ($file) = @_;
    my ( $fh, %vips, $lineno );
    my ( $nag, %oldvip );

    verbose( "Parsing $file...", 2 );
    $lineno = 0;

    open( $fh, "<", $file ) || die("Unable to open $file: $!\n");
    while ( my $line = <$fh> ) {
        my ( $af, $ip, $dscp );

        $lineno++;
        $line =~ s/#.*//;
        $line =~ s/^\s*//;
        $line =~ s/\s+$//;
        chomp($line);

        next unless $line;

        $line = lc($line);
        if ( $line =~ m/^(ip|dscp|type)\s*(?:=\s*(\S+))?$/ ) {

            # Bug [5046439]: old style config file
            if ( !$nag ) {
                error("1.x style (old) config file encountered.");
                error("Please read yvip.conf(5) and update your config files.");
                $nag = 1;
            }
            $oldvip{$1} = $2;
        }
        elsif ( $line =~ m/^(\S+?)\s*(?:=\s*(\S+))?$/ ) {
            $ip   = $1;
            $dscp = $2;
        }
        else {
            error( "Syntax error in $file (line $lineno).", EXIT_FAILURE );

            # NOTREACHED
        }

        # We're nice and allow old style configs after having
        # complained above.  It's messy, though.
        #
        # If we have any old entries...
        if ( scalar( keys(%oldvip) ) ) {
            if ( !( $oldvip{"type"} && $oldvip{"ip"} ) ) {

                # ...then we need at least 'type' and 'ip'...
                next;
            }
            elsif ( ( $oldvip{"type"} eq "l3-dsr" ) && !$oldvip{"dscp"} ) {

                # ...and if l3dsr, then we need dscp.
                next;
            }
            else {

                # Here we have a complete old-style vip, so
                # let's set our new-style variables.  Note that
                # 'dscp' may well be unset (in case of 'dsr'),
                # which is fine.
                $ip   = $oldvip{"ip"};
                $dscp = $oldvip{"dscp"};
            }
        }

        # If we get here, we either have a new-style config file or
        # parsed the old-style config file in its entirety and prepped
        # our new-style variables.
        if ($ip) {
            if ( inet_pton( AF_INET, $ip ) ) {
                $af = "AF_INET";
            }
            elsif ( inet_pton( AF_INET6, $ip ) ) {
                $af = "AF_INET6";
            }
            else {
                error( "Invalid IP '$ip' in $file (line $lineno).",
                    EXIT_FAILURE );

                # NOTREACHED
            }
            $vips{$ip} = {
                'type' => $dscp ? "l3-dsr" : "dsr",
                'ip'   => $ip,
                'dscp' => $dscp,
                'af'   => $af
            };
        }
    }
    close($fh);

    # When stopping, we want to stop everything even if there are errors.
    if ( $OPTS{'ACTION'} ne "stop" ) {
        foreach my $vip ( keys(%vips) ) {
            verifyVip( $vips{$vip}, $file );
        }
    }

    return \%vips;
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
    my ( @files, %vips );

    verbose("Parsing all input...");

    if ( $OPTS{'d'} ) {
        my $dh;
        opendir( $dh, $OPTS{'d'} )
          || die( "Unable to open directory " . $OPTS{'d'} . ": $!\n" );
        push( @files,
            grep { -f "$OPTS{'d'}/$_" && $_ !~ /\.rej$/ } readdir($dh) );
        closedir($dh);

        @files = map { $OPTS{'d'} . '/' . $_ } @files;
        $OPTS{'ALL'} = 1;
    }

    if ( $OPTS{'f'} ) {
        push( @files, $OPTS{'f'} );
    }

    foreach my $f (@files) {
        if ( !-s $f ) {
            verbose( "Skipping empty config file $f.", 2 );
            next;
        }
        my $vr        = parseFile($f);
        my %file_vips = %{$vr};
        foreach my $vip ( keys(%file_vips) ) {

            # When stopping, we want to stop everything even if
            # there are # errors.
            if ( $OPTS{'ACTION'} ne "stop" ) {
                verifyVipAgainstAllVips( $file_vips{$vip}, \%vips );
            }
            $vips{$vip} = $file_vips{$vip};
        }
    }

    return \%vips;
}

# function : runCommand
# purpose  : run the given command via 'system'
# inputs   : a full command string
# returns  : exit status of the command

sub runCommand($) {
    my ($cmdline) = @_;

    verbose( "Running '$cmdline'...", 5 );
    my $rval = ( system($cmdline) >> 8 );
    return $rval;
}

# function : runCommandOrDie
# purpose  : run the given command and die if it returns unsuccessfully
# inputs   : a full command string
# returns  : nothing, may die on failure

sub runCommandOrDie($) {
    my ($cmd) = @_;

    my $rval = runCommand($cmd);
    if ( $rval != 0 ) {
        error( "Unable to run '$cmd' (returned $rval).", EXIT_FAILURE );

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
    my ( $msg, $level ) = @_;
    my $char = "=";

    return unless $OPTS{'v'};

    $char .= "=" x ( $level ? ( $level - 1 ) : 0 );

    if ( !$level || ( $level <= $OPTS{'v'} ) ) {
        print STDERR "$char> $msg\n";
    }
}

# function : verifyVipAgainstAllVips
# purpose  : check all the given vip does not conflict with any existing VIPs
#            at this point, this is pretty much restricted to checking that
#            we have no "IP<->dscp" pair conflicts
# inputs   : a hashref of all VIPs
# returns  : nothing, dies if conflicts are found

sub verifyVipAgainstAllVips($$) {
    my ( $avr, $allvr ) = @_;
    my %aVip    = %{$avr};
    my %allVips = %{$allvr};

    verbose("Verifying all VIP configurations...");

    foreach my $vip ( keys(%allVips) ) {
        my $existing_dscp = $allVips{$vip}{'dscp'};
        my $new_dscp      = $aVip{'dscp'};
        if ( ( $aVip{'ip'} eq "$vip" ) && ( $aVip{'dscp'} != $existing_dscp ) )
        {
            error(
"$vip (dscp: $existing_dscp) conflicts with $vip (dscp: $new_dscp).",
                EXIT_FAILURE
            );

            # NOTREACHED
        }
    }
}

# function : verifyOptions
# purpose  : verify that any options we if-else later on have valid values
# inputs   : none, operates on %OPTS
# returns  : nothing, may die on error

sub verifyOptions() {
    if ( !$OPTS{'ACTION'}
        || ( !defined( $SUPPORTED_ACTIONS{ $OPTS{'ACTION'} } ) ) )
    {
        error( "ACTION is unset or invalid.", EXIT_FAILURE );

        # NOTREACHED
    }

    if ( !$OPTS{'OS'} || ( !defined( $SUPPORTED_OS{ $OPTS{'OS'} } ) ) ) {
        error( "OS is unset or invalid.", EXIT_FAILURE );

        # NOTREACHED
    }
}

# function : verifyVip
# purpose  : verify that a given vip configuration is valid
# inputs   : a vip config opbject (ie hash ref), a config file
# returns  : nothing, may error on error

sub verifyVip($$) {
    my ( $vr, $file ) = @_;
    my %vip = %{$vr};

    foreach my $key ( "ip", "type" ) {
        if ( !$vip{$key} ) {
            error( "Invalid VIP config -- '$key' missing from $file.",
                EXIT_FAILURE );

            # NOTREACHED
        }
    }

    if ( !$SUPPORTED_TYPES{ $vip{'type'} } ) {
        error(
            "Invalid VIP config -- type '" . $vip{'type'} . "' not supported.",
            EXIT_FAILURE
        );

        # NOTREACHED
    }

    if ( ( $vip{'type'} eq "l3-dsr" ) && !$vip{'dscp'} ) {
        error( "Invalid VIP config -- l3-dsr type is missing dscp key.",
            EXIT_FAILURE );

        # NOTREACHED
    }

    if ( ( $vip{'type'} eq "dsr" ) && $vip{'dscp'} ) {
        error( "Invalid VIP config -- non-l3-dsr type has a dscp field.",
            EXIT_FAILURE );

        # NOTREACHED
    }
}

###
### Main
###

init();
verifyOptions();

my %vipConfigs = %{ parseInput() };

if ( $OPTS{'ACTION'} eq "check" ) {
    print "Syntax OK.\n";
    exit(EXIT_SUCCESS);

    # NOTREACHED
}

verbose("Configuring host for all VIPs ("
      . scalar( keys(%vipConfigs) )
      . " total)..." );
foreach my $vip ( keys(%vipConfigs) ) {
    configureVip( $vipConfigs{$vip} );
}

my $act = $OPTS{'ACTION'};
if ( $act =~ /^(stop)$/ ) {
    $act = $1 . "p";
}
elsif ( $act =~ /^(start)$/ ) {
    $act = $1;
}

printf "All VIPs ${act}ed.\n";

# We are done
exit(EXIT_SUCCESS);
