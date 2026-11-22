#!/usr/bin/perl
# Spike 3.6 throwaway: wall-clock limit that works for agy. `perl -e 'alarm N; exec ...'` does NOT stop agy (a Go binary: SIGALRM is ignored unless the program asks for it; measured: still running after 126 s with alarm 60).
# Usage: with-timeout.pl <seconds> <cmd> [args...]   -> runs cmd in a NEW process group, TERM at <seconds>, KILL 10 s later (the same TERM-then-KILL order as ADR-005 §7), rc 124 on timeout, otherwise cmd's rc. stdout/stderr/stdin are inherited.
use strict; use warnings; use POSIX qw(:sys_wait_h setpgid);
my $secs = shift @ARGV; die "usage\n" unless defined $secs && $secs =~ /^\d+$/ && @ARGV;
my $pid = fork(); die "fork: $!" unless defined $pid;
if ($pid == 0) { setpgid(0, 0); exec @ARGV or die "exec: $!"; }
setpgid($pid, $pid);
my ($timed, $deadline, $killed) = (0, time + $secs, 0);
while (1) {
  my $r = waitpid($pid, WNOHANG);
  if ($r == $pid) { my $rc = $? & 127 ? 128 + ($? & 127) : $? >> 8; exit($timed ? 124 : $rc); }
  if (!$timed && time >= $deadline) { $timed = 1; kill 'TERM', -$pid; $deadline = time + 10; }
  elsif ($timed && !$killed && time >= $deadline) { $killed = 1; kill 'KILL', -$pid; }
  select(undef, undef, undef, 0.2);
}
