package Gtk2IPMessenger::InputMessage;

use warnings;
use strict;
use Glib qw( TRUE FALSE );

sub new_input_message {
    my $self = shift;

    my $tview = Gtk2::TextView->new();
    # save input_message
    $self->input_message($tview);
    return $tview;
}

sub new_send_button {
    my( $self, $user ) = @_;
    my $button = Gtk2::Button->new_from_stock('gtk-ok');
    my $input = $self->input_message;
    $button->signal_connect(
        clicked => sub {
            my $buf = $input->get_buffer;
            my $text =
                $buf->get_text( $buf->get_start_iter, $buf->get_end_iter, 0 );
            $buf->set_text("");
            return unless $text;

            my $result = $self->send_message( $user, $text );
            unless ($result) {
                $self->alert_message("Failed sending message.\nPlease try again.");
                return;
            }

            $self->add_message_log( 'to', $text, $user );
        }
    );

    $self->send_button($button);
    return $button;
}

sub send_message {
    my( $self, $user, $raw_text ) = @_;
    my $text  = $self->from_utf8($raw_text);
    my $ipmsg = $self->ipmsg;

    my $command = $ipmsg->messagecommand('SENDMSG')->set_secret;

    if ( $user->encrypt and $ipmsg->encrypt ) {
        if ( not $user->pubkey ) {
            $ipmsg->send(
                {
                    command => $ipmsg->messagecommand('GETPUBKEY'),
                    option =>
                        sprintf( "%x", $ipmsg->encrypt->support_encryption ),
                    peeraddr => $user->peeraddr,
                    peerport => $user->peerport,
                }
            );

            local $SIG{ALRM} = sub { die "timeout\n" };
            alarm(1);
            eval { $ipmsg->recv };
            if ( $@ and $@ eq "timeout\n" ) {
                alarm(0);
                return;
            }
            alarm(0);
        }

        $text = $ipmsg->encrypt->encrypt_message( $text, $user->pubkey, );
        $command->set_encrypt;
    }

    $ipmsg->send(
        {
            command  => $command,
            option   => $text,
            peeraddr => $user->peeraddr,
            peerport => $user->peerport,
        }
    );

    return 1;
}

1;
