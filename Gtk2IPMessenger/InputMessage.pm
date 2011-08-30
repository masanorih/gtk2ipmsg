package Gtk2IPMessenger::InputMessage;

use warnings;
use strict;
use Glib qw( TRUE FALSE );
use File::Basename qw(basename);

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
    my $input  = $self->input_message;
    $button->signal_connect(
        clicked => sub {
            my $buf = $input->get_buffer;
            my $text =
                $buf->get_text( $buf->get_start_iter, $buf->get_end_iter, 0 );
            $buf->set_text("");
            return unless $text;

            my $result = $self->send_message( $user, $text );
            unless ($result) {
                $self->alert_message("failed to send.\nplease try again.");
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
            my $result = $self->send_GETPUBKEY($user) or return;
        }
        $text = $ipmsg->encrypt->encrypt_message( $text, $user->pubkey );
        $command->set_encrypt;
    }

    my $label_attach = $self->label_attach->get_label;
    if ( 'add attach file' ne $label_attach ) {
        $command->set_fileattach;
        my $result = $self->add_attach( $label_attach );
        $text .= $result if $result;
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

sub send_GETPUBKEY {
    my( $self, $user ) = @_;
    my $ipmsg = $self->ipmsg;
    $ipmsg->send(
        {
            command  => $ipmsg->messagecommand('GETPUBKEY'),
            option   => sprintf( "%x", $ipmsg->encrypt->support_encryption ),
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
    return 1;
}

our $attach_dir = $ENV{HOME};

sub new_attach_button {
    my($self) = @_;
    my $button = Gtk2::Button->new_from_stock('gtk-open');
    $button->signal_connect(
        clicked => sub {
            my $dialog = Gtk2::FileChooserDialog->new(
                'attach', undef,
                'open',
                'gtk-cancel' => 'cancel',
                'gtk-ok'     => 'ok'
            );
            $dialog->set_current_folder($attach_dir);
            if ( 'ok' eq $dialog->run ) {
                $attach_dir = $dialog->get_current_folder;
                my $file = $dialog->get_filename;
                $self->label_attach->set_label($file);
                $self->label_attach->hide;
                $self->{pbar}->set_text( basename($file) );
                $self->{pbar}->show;
            }
            $dialog->destroy;
        }
    );
    $self->attach_button($button);
    return $button;
}

sub new_close_attach {
    my($self) = @_;

    my $button = Gtk2::Button->new_from_stock('gtk-clear');
    $button->signal_connect(
        clicked => sub {
            $self->{pbar}->set_text("");
            $self->{pbar}->set_fraction(0);
            $self->{pbar}->hide;
            $self->label_attach->set_label('add attach file');
            $self->label_attach->show;
        }
    );
    return $button;
}

1;
