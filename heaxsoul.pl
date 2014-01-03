#!/usr/bin/perl -w

use warnings;
use strict;
use IO::Socket::INET;
use Digest::MD5 qw(md5_hex);

###############################################
# User config
my %config = (
    user        => "logi_n",
    password    => "your_password",
    server      => "ns-server.epita.fr",
    port        => "4242",
    client_vers => "HeaxSoul v0.1",
    location    => "Episteack"
);
###############################################

$| = 1;
use constant false => 0;
use constant true  => 1;

my %handlers = (
    "salut"     =>      \&HandleSalut,
    "rep"       =>      \&HandleRep,
    "ping"      =>      \&HandlePing,
);

sub HandleSalut {
    my ($sock, $func, $socknum, $hash, $cli_host, $port, $time) = @_;

    my $data = "auth_ag ext_user none none\n";
    $sock->send($data);

    print "Waiting serveur auth request\n";
    die "Fail to connect\n" unless &WaitAnswer($sock);

    $data = "$hash-$cli_host/$port$config{password}";
    my $md5 = md5_hex($data);
    my $user_data = $config{client_vers};
    my $location = $config{location};
    $user_data =~ s/ /%/g;
    $location =~ s/ /%/g;
    $data = "ext_user_log $config{user} $md5 $user_data $location\n";

    print "Try to connect ...\n";
    $sock->send($data);
    die "Fail to connect\n" unless &WaitAnswer($sock);
    print "Connected !\n";

    $data = "state actif\n";
    $sock->send($data);
}

sub HandleRep {
    my ($sock, $func, $code, $sep, @infos) = @_;
    
    if ($code != "002")
    {
        my $rep = join(' ', @infos);
        print "Error: $rep\n";
        return false;
    }
    return true;
}

sub HandlePing {
    my ($sock, $func, $time) = @_;

    my $data = "ping\n";
    $sock->send($data);
}

sub GetInputArray {
    my $data = $_[0];

    chomp($data);
    return split(/ /, $data);
}

sub WaitAnswer {
    my $sock = $_[0];

    my $data = <$sock>;
    if (!defined $data) {
        print "Remote host closed connection\n";
        return false;
    }
    my @params = &GetInputArray($data);
    return &HandleRep($sock, @params);
}

sub OpenSockConnection {
    return new IO::Socket::INET(PeerAddr => $config{server},
                                    PeerPort => $config{port},
                                    Proto => 'tcp')
                                    or die "Fail to create socket: $!\n";
}

sub main {
    print "Connecting to $config{server}:$config{port} with user $config{user}\n";

    my $sock = undef;
    my $conn_count = 1;

    while (defined "The world is cool"){
        while (!defined $sock) {
            print "Try to connect to remote server (Attempt $conn_count)\n";
            $sock = &OpenSockConnection();
            if (!defined $sock) {
                ++$conn_count;
                sleep(2);
            }
        }

        $conn_count = 1;
        print "Connection open !\n";

        while (my $data = <$sock>) {
            if (!defined $data) {
                print "Remote host close socket, try to re-login\n";
                $sock = &OpenSockConnection();
            } else {
                my @params = &GetInputArray($data);

                if (exists $handlers{$params[0]}) {
                    $handlers{$params[0]}->($sock, @params) if exists $handlers{$params[0]};
                } else {
                    print "Receiv unknow message: $params[0]\n";
                }
            }
        }
        $sock = undef;
    }
    print "Closing HeaxSoul, Bye\n";
}

#############
# Main function
&main();
#############
