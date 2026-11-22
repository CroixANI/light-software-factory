#!/bin/sh
# Spike 3.4 E11: run by the codex shell tool under the profile. Tries four escapes, then stays in the foreground for 60 s so the harness can kill mid-run.
# $1 = step tmp dir, $2 = gateway port, $3 = run tag (markers are LSFMARK_<tag>_A..D, so a scan matches only this run). All fds are redirected so the tool call does not wait on the children.
T=$1; P=$2; TAG=${3:?tag}; export PROBEPORT=$P PROBET=$T TAG
# a) nohup + background
nohup perl -e 'sleep 600' "LSFMARK_${TAG}_A" >/dev/null 2>&1 </dev/null &
# b) setsid (new session, leaves the process group)
perl -e 'use POSIX; POSIX::setsid(); exec "/usr/bin/perl","-e","sleep 600","LSFMARK_$ENV{TAG}_B"' >/dev/null 2>&1 </dev/null &
# c) double fork (reparented to launchd)
( perl -e 'sleep 600' "LSFMARK_${TAG}_C" >/dev/null 2>&1 </dev/null & ) &
# d) setsid + double fork + network probe against the Step's gateway port (CONNECT probe against the gateway every second: only a `reply:HTTP/1.1 200` counts as network; a bare connect() succeeds even with the port closed when run under the desktop app)
perl -e 'use POSIX; use IO::Socket::INET; $SIG{PIPE}="IGNORE"; if(fork){exit} POSIX::setsid(); if(fork){exit} for(1..600){ my $so=IO::Socket::INET->new(PeerAddr=>"127.0.0.1",PeerPort=>$ENV{PROBEPORT},Timeout=>1); my $r="connect-fail"; if($so){ print $so "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n"; my $l; eval { local $SIG{ALRM}=sub{die}; alarm 2; $l=<$so>; alarm 0 }; $r=defined $l ? "reply:".substr($l,0,20) : "no-reply"; } open(L,">>","$ENV{PROBET}/probe.log"); print L time()," $r\n"; close L; sleep 1 }' "LSFMARK_${TAG}_D" >/dev/null 2>&1 </dev/null
sleep 60
