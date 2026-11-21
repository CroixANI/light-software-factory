#!/bin/sh
# Spike 3.2 E11: run by the claude Bash tool under the profile. Tries four escapes, then stays in the foreground for 60 s so the harness can kill mid-run.
# $1 = step tmp dir, $2 = gateway port. All fds are redirected so the tool call does not wait on the children.
T=$1; P=$2; export PROBEPORT=$P PROBET=$T
# a) nohup + background
nohup perl -e 'sleep 600' LSFMARK_A >/dev/null 2>&1 </dev/null &
# b) setsid (new session, leaves the process group)
perl -e 'use POSIX; POSIX::setsid(); exec "/usr/bin/perl","-e","sleep 600","LSFMARK_B"' >/dev/null 2>&1 </dev/null &
# c) double fork (reparented to launchd)
( perl -e 'sleep 600' LSFMARK_C >/dev/null 2>&1 </dev/null & ) &
# d) setsid + double fork + network probe against the Step's gateway port (logs ok/fail every second)
perl -e 'use POSIX; use IO::Socket::INET; if(fork){exit} POSIX::setsid(); if(fork){exit} for(1..600){ my $s=IO::Socket::INET->new(PeerAddr=>"127.0.0.1",PeerPort=>$ENV{PROBEPORT},Timeout=>1); open(L,">>","$ENV{PROBET}/probe.log"); print L time()," ",($s?"connect-ok":"connect-fail"),"\n"; close L; sleep 1 }' LSFMARK_D >/dev/null 2>&1 </dev/null
sleep 60
