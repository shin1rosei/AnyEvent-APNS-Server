package AnyEvent::APNS::Server;
use strict;
use warnings;
our $VERSION = '0.01';

use utf8;
use Encode;

use Mouse;
use Log::Minimal;

use AnyEvent::APNS;
use AnyEvent::MPRPC::Server;

use Cache::LRU;
use Try::Tiny;

has certificate => (
    is => 'ro',
);

has private_key => (
    is => 'ro',
);

has is_sandbox => (
    is => 'ro',
);

has port => (
    is => 'ro',
);

has debug_apns_port => (
    is => 'ro',
);

has sent_token => (
    is      => 'rw',
    default => sub {
        Cache::LRU->new(size => 10000);
    },
);

has message_queue => (
    is      => 'rw',
    default => sub {[];},
);

has apns => (
    is      => 'rw',
    clearer => 'close_apns',
);

has on_error_response => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub { sub { warn @_ } },
);

has _last_connect_at => (
    is => 'rw',
);

has _last_send_at => (
    is => 'rw',
);

no Any::Moose;

sub run {
    my $self = shift;

    my $cv = AnyEvent->condvar;

    my $server = AnyEvent::MPRPC::Server->new(
        port        => $self->port,
        on_error    => sub {},
        on_accept   => sub {
            infof "[mprpc server] on_accept";
            $self->_last_send_at(time);
        },
        on_dispatch => sub {
            infof "[mprpc server] on_dispatch";
        },

    );
    $server->reg_cb(
        notify => sub {
            my ($res_cv, $params) = @_;

            my $p = $params->[0];
            infof "[mprpc server] send notify";

            if ($self->apns && $self->apns->connected) {
                my $identifier = $self->apns->send(pack("H*", $p->{token}), {
                    aps => {
                        alert => decode_utf8($p->{msg}),
                        sound => 'default',
                    },
                });
                $self->sent_token->set($identifier, $p->{token});

                infof "[mprpc server] send notify complete %s", $p->{token};
            }
            else {
                infof "[apns] push queue";
                push @{$self->message_queue}, $p; #つなぎ終わったら送信
                $self->_connect_to_apns;
            }

            $res_cv->result('ok');
        },
    );

    my $t; $t = AnyEvent->timer( 
        # 最終送信日時から１分以上たっていたらAPNSとの接続を破棄する
        after    => 60,
        interval => 60,
        cb    => sub {
            if ($self->apns) {
                if (time - $self->_last_send_at > 60) {
                    try {$self->close_apns};
                    infof "[apns] close apns";
                }
            }
        },
    );

    $cv->recv;
}

sub _connect_to_apns {
    my $self = shift;

    return if ($self->apns);

    $self->apns(AnyEvent::APNS->new(
        certificate => $self->certificate,
        private_key => $self->private_key,
        sandbox     => $self->is_sandbox,
        on_error    => sub {
            my ($handle, $fatal, $message) = @_;

            my $t; $t = AnyEvent->timer(
                after    => 0,
                interval => 10,
                cb       => sub {
                    undef $t;
                    infof "[apns] reconnect";
                    $self->_last_connect_at(time);
                    $self->apns->connect;
                },
            );

            # 即座に再接続
            infof "[apns] error fatal: $fatal message: $message";
        },
        on_connect  => sub {
            infof "[apns] on_connect";
            $self->_last_connect_at(time);

            if (@{$self->message_queue}) { #未送信メッセージがあれば送信する
                while (my $q = shift @{$self->message_queue}) {
                    $self->apns->send(pack("H*", $q->{token}), {
                        aps => {
                            alert => decode_utf8($q->{msg}),
                            sound => 'default',
                        },
                    });
                    infof "[apns] send from queue ".$q->{token};
                }
            }
        },
        on_error_response => sub {
            my ($identifier, $state) = @_;

            if ($state == 8) { #不正なtoken
                my $token = $self->sent_token->get($identifier) || undef;
                $self->on_error_response($token, @_);
            }
        },
    ));

    if ($self->debug_apns_port) {
        $self->apns->debug_port($self->debug_apns_port);
    }

    $self->apns->connect;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

AnyEvent::APNS::Server - server module for connecting to Apple Push Notification (APNS).

=head1 SYNOPSIS

  use AnyEvent::APNS::Server;

  AnyEvent::APNS::Server->new({
    is_sandbox  => 1 or 0,
    certificate => <certificate string>,
    private_key => <key_file string>,
    port        => 8888,
  })->run;

=head1 DESCRIPTION

This module is a server module which manages connection with APNS efficiently.

=head1 AUTHOR

Shinichiro Sei E<lt>shin1rosei {at} kayac.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
