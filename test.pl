#!/usr/local/bin/perl -w
## A simple tester for a Perl RFC 1413 Ident server
use strict;
use warnings;

my $host = 'localhost';
my $port = '11300';

use IO::Socket;
my $socket = IO::Socket::INET->new( 
    PeerAddr => $host,
    PeerPort => $port,
       proto => "tcp",
     timeout => 60,
        Type => SOCK_STREAM
) or die "_get_socket: Error in creating socket: $!\n" ;

my $local_port = $socket->sockport() || die "Couldn't get local port: $!\n";

#print "Sending: '$local_port, $port'\n";

print $socket "$local_port, $port\n";

my $resp = <$socket>;
chomp $resp;

print "$resp\n";
