#!/usr/local/bin/perl
=head1 NAME

ident.pl - An RFC 1413 compliant(ish) Ident server

=head1 SYNOPSIS

sudo ident.pl [options] command <arg>

ident.pl opens port 113 so it needs root permissions
            
=head1 OPTIONS

=over

=item B<--help|-h>

Print this usage information and exit.

=item B<--debug|-d>

Print debugging info into the log file (/tmp/logfile_ident).

=item B<command>

Valid commands are:

=back

=over 8

=item B<*>

B<random>       - returns a random username when queried

=item B<*>

B<uid>          - returns the actual username of the user doing the querying

=item B<*>

B<always E<lt>argE<gt>> - always returns 'arg' when queried

=back

=over

=item B<E<lt>argE<gt>>

A mandatory argument for the 'always' command.  This value is what is
returned whenever the Ident server is queried under the auspices of the
'always' command.

=back
         
=head1 DESCRIPTION

C<ident.pl> An RFC 1413 compliant(ish) Ident server coding challenge submission

=cut

=head1 REQUIREMENTS

B<Net::IdentServer> - Installed via ypan/cpan

Net::IdentServer is based on Net::Server::Fork so it should handle multiple 
connections without issue.

=head1 AUTHOR

Marc Kandel C<< <mkandel at cpan.org> >>

=cut

use strict;
use warnings;

use Carp;
use Getopt::Long;
Getopt::Long::Configure ("bundling");
use Pod::Usage;

my $help;
my $mydebug;

GetOptions(
    "help|h"  => sub{ pod2usage( 1 ); },
    "debug|d" => \$mydebug,
);

my $prog = $0;
$prog =~ s/^.*\///;

## Read in commandline arguments not cought by GetOptions:
my $command = shift @ARGV || 'random'; ## Default to 'random' per requirements
my $arg     = shift @ARGV || undef;

print "Command: '$command'\n";

## die if more than one command is passed in:
if ( $arg && 
    ( $command =~ m/\A(?:random|uid|always)\z/ && $arg =~ m/\A(?:random|uid|always)\z/ )
    ){
        die "More than one command is not allowed!\n";
}

print "command: '$command'\n" if $mydebug;
print "arg    : '$arg'\n" if $arg && $mydebug;

## This part is basically a wrapper to call our subclass so we can override
##   a function and have our custom behavior as per requirements
my $srv = new MyIdentServer({
    command => $command, 
    arg => $arg 
});
run $srv;

## And here's the subclass definition
package MyIdentServer;

use base qw( Net::IdentServer );

use Data::Dumper;
# Some Data::Dumper settings:
local $Data::Dumper::Useqq  = 1;
local $Data::Dumper::Indent = 3;

#    FUNCTION: new()
#
#   ARGUMENTS: command - a mandatory choice of "random", "always" or "uid"
#              arg     - only needed by "always", this is the value to return
# 
#     RETURNS: a blessed reference to a MyIdentServer object
#              (a customized Net::IdentServer object)

sub new{
    my $class = shift;
    my $params = shift;
    
    my $self = $class->SUPER::new( 
        @_, 
        shhh => 1, 
        allow => '*',
    );

    $self->{ command } = $params->{ command };

    if ( $command eq 'random' ){
        ## Populate users from /etc/passwd once while constructing
        ##   the object, if and only if we're using 'random'
        my $passfile = '/etc/passwd';
        open my $IN, '<', $passfile or die "Couldn't open password file: $!\n";
        while ( <$IN> ){
            ## We just want the username, it's the 1st field, ignore the rest
            my ( $name, @rest ) = split ':', $_;
            push @{ $self->{ users } }, $name;
        }
        close $IN or die "Error closing password file: $!\n";
    } elsif ( $command eq 'uid' ){
        ## Provide user info for user tied to UID
        ## For now, do nothing.  This is the default behavior 
        ##   of Net::IdentServer
        ## I could remove this elsif but I'd have to check for 'uid' somewhere
        ##   else anyway
    } elsif ( $command eq 'always' ){
        ## Always return $arg so store it in our object for later retrieval
        ## die if we don't have the necessary argument
        die "Argument needed for 'always' ...\n" unless $params->{ arg };
        $self->{ arg } = $params->{ arg };
    } else {
        die "Unrecognized command '$command' ... exiting!!\n";
    }
    print Dumper $self if $mydebug;
    return $self;
}

#    FUNCTION: print_response() - overridden method from Net::IdentServer
#                                 base class.  This is where my customization
#                                 magic happens ...
#
#   ARGUMENTS: none
# 
#     RETURNS: none

sub print_response{
    my $self = shift;
    $self->log( 1, "Got into 'print_response()' ..." ) if $mydebug;
    ## Per the API docs, these are passed into this method
    my ( $local, $remote, $type, $info ) = @_;
    $self->log( 1, "$local, $remote, $type, $info" ) if $mydebug;

    ## Per requirements:
    ## "If the client sends you an invalid request, you
    ##    must disconnect the client (and only that client) immediately without
    ##    sending a reply."
    ## So, if $info == 'UNKNOWN-ERROR', we'll die
    die if ( $info eq 'UNKNOWN-ERROR' );

    if ( $self->{ command } eq 'always' ){
        $info = $self->{ arg };
    } elsif ( $self->{ command } eq 'random' ){
        $info = $self->get_rand_user();
    }

    ## Per requirements, we always return 'UNIX'
    $type = 'UNIX';

    $self->log( 1, "$local, $remote, $type, $info" ) if $mydebug;

    ## Now that we've manipulated the data, let the API do the rest:
    $self->SUPER::print_response( $local, $remote, $type, $info );
}

#    FUNCTION: get_rand_user()
#
#   ARGUMENTS: none
# 
#     RETURNS: a random username parsed from /etc/passwd

sub get_rand_user{
    my $self = shift;
    $self->log( 1, "Got into 'get_rand_user()' ..." ) if $mydebug;
    
    my $rand_num = rand( scalar @{ $self->{ users } } - 1 );

    return $self->{ users }->[ $rand_num ];
}

1;
__END__

