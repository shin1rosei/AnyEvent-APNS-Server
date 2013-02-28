package AnyEvent::APNS::Client;

use strict;
use warnings;

use AnyEvent::MPRPC::Client;
use Log::Minimal;

use Mouse;

has host => (
    is       => 'ro',
    required => 1,
);

has port => (
    is       => 'ro',
    required => 1,
);

has client => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        AnyEvent::MPRPC::Client->new({
            host => $self->host,
            port => $self->port,
        });
    },
);

sub notify {
    my ($self, $device_token, $msg) = @_;
    critf("message not set") unless $msg;

    my $cv = $self->client->call('notify' => {
        token => $device_token,
        msg   => $msg,
    });

    my $res;
    eval { $res = $cv->recv};
    if (my $error = $@) {
        warnf "apns send error: %s$error";
    }
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

AnyEvent::APNS::Client -

=head2 SYNOPSIS

  use AnyEvent::APNS::Client;

  $client = AnyEvent::APNS::Client->new({
     host => 'server-host',
     port => 8888,
  });

  $client->notify(
     $device_token, #HEX
     $msg,
  );

=head1 DESCRIPTION

AnyEvent::APNS::Client is client module for AnyEvent::APNS::Server.

