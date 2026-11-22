use IO::Socket::INET; my $s=IO::Socket::INET->new(PeerAddr=>"127.0.0.1",PeerPort=>($ARGV[0]||$ENV{PROBEPORT}||8911),Timeout=>2); if(!$s){print "connect-fail $!\n";exit}
print $s "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n"; $s->timeout(3); my $l=<$s>; print defined $l ? "reply: $l" : "no-reply\n";
