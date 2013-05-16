use strict;
use warnings;
use Test::TCP;
use AnyEvent;

use AnyEvent::APNS::Server;
use AnyEvent::APNS::Client;
use AnyEvent::Socket;

use Test::More;
use JSON::XS;

my $apns_port;
my $cv = AnyEvent->condvar;

$apns_port = empty_port;

tcp_server undef, $apns_port, sub {
    my ($fh) = @_
      or die $!;

    my $handle; $handle = AnyEvent::Handle->new(
        fh       => $fh,
        on_eof   => sub {
        },
        on_error => sub {
            die $!;
            undef $handle;
        },
        on_read => sub {
            $_[0]->unshift_read( chunk => 1, sub {} );
        },
    );

    $handle->push_read( chunk => 1, sub {
        is($_[1], pack('C', 1), 'command ok');
    });

    $handle->push_read( chunk => 4, sub {
        is($_[1], pack('N', 1), 'identifier ok');
    });

    $handle->push_read( chunk => 4, sub {
        my $expiry = unpack('N', $_[1]);
        is( $expiry, time() + 3600 * 24, 'expiry ok');
    });

    $handle->push_read( chunk => 2, sub {
        is($_[1], pack('n', 32), 'token size ok');
    });

    $handle->push_read( chunk => 32, sub {
        is($_[1], 'd'x32, 'token ok');
    });

    $handle->push_read( chunk => 2, sub {
        my $payload_length = unpack('n', $_[1]);

        $handle->push_read( chunk => $payload_length, sub {
            my $payload = $_[1];
            my $p = decode_json($payload);

            is(length $payload, $payload_length, 'payload length ok');
            is $p->{aps}->{alert}, 'test', 'value of alert';
            is $p->{aps}->{sound}, 'default', 'value of sound';
        });

        my $t; $t = AnyEvent->timer(
            after => 0.5,
            cb    => sub {
                undef $t;
                $cv->send;
                done_testing;
            },
        );
    });
};

test_tcp (
    server => sub {
        my $port = shift;
        local $Log::Minimal::LOG_LEVEL = "NONE";

        my $s = AnyEvent::APNS::Server->new({
            is_sandbox      => 1,
            certificate     => 'dummy',
            private_key     => 'dummy',
            port            => $port,
            debug_apns_port => $apns_port,
        })->run;

    },
    client => sub {
        my $port = shift;

        my $client = AnyEvent::APNS::Client->new({
            host => '127.0.0.1',
            port => $port,
        });
        $client->notify(unpack("H*", 'd'x 32), "test");
        $cv->recv;
    },
);


