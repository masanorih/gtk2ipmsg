package Gtk2IPMessenger::MessageLog;

use warnings;
use strict;
use Gtk2::Pango;
use Glib qw( TRUE FALSE );
use POSIX qw( strftime );

sub new_message_log {
    my( $self, $user ) = @_;

    # Generate TextView
    my $tview = Gtk2::TextView->new();
    $tview->set_editable(FALSE);
    $tview->set_cursor_visible(FALSE);
    $tview->set_wrap_mode('word');
    my $buffer = $tview->get_buffer();

    $buffer->create_tag(
        'from',
        foreground => 'darkgreen',
        weight     => PANGO_WEIGHT_BOLD,
    );
    $buffer->create_tag(
        'from_message',
        foreground    => 'darkgreen',
        'left-margin' => 20,
    );

    $buffer->create_tag(
        'to',
        foreground => 'blue',
        weight     => PANGO_WEIGHT_BOLD,
    );
    $buffer->create_tag(
        'to_message',
        foreground    => 'blue',
        'left-margin' => 20,
    );

    # save message_log
    my $message_log = $self->message_log;
    $message_log->{ $user->key } = $tview;
    $self->message_log($message_log);
    return $tview;
}

sub add_message_log {
    my( $self, $tag, $text, $user ) = @_;

    my $header;
    # from user
    if ( $tag eq 'from' ) {
        $header = sprintf "[%s] %s (%s/%s)\n",
            substr( $user->time, 11, 9),
            $user->nick || '',
            $user->group || '',
            $user->host || '';
    }
    # to user
    else {
        my $ipmsg = $self->ipmsg;
        $header = sprintf "[%s] %s (%s/%s)\n",
            strftime( "%H:%M:%S", localtime ),
            $ipmsg->nickname,
            $ipmsg->groupname,
            $ipmsg->hostname;
    }

    my $log_buf = $self->message_log->{ $user->key }->get_buffer;
    my $iter    = $log_buf->get_end_iter;
    $log_buf->insert_with_tags_by_name( $iter, $self->to_utf8($header), $tag, );
    $iter = $log_buf->get_end_iter;
    chomp $text;
    $text .= "\n";
    $text =~ s/\0//g;
    $log_buf->insert_with_tags_by_name( $iter, $text, $tag . '_message', );
}

sub open_message_button {
    my( $self, $user ) = @_;
    my $ipmsg = $self->ipmsg;
    my $button = Gtk2::Button->new('open');
    $button->set_sensitive(FALSE) unless $self->has_message_from_user($user);
    $button->signal_connect(
        clicked => sub {
            my( $result, $i ) = $self->has_message_from_user($user);
            if ($result) {
                my $m = splice @{ $ipmsg->message }, $i, 1;
                # if message is sealed
                my $command = $ipmsg->messagecommand( $m->command );
                if ( $command->get_secret ) {
                    my $message_ref = {
                        command  => $ipmsg->messagecommand('READMSG'),
                        peeraddr => $user->peeraddr,
                        peerport => $user->peerport,
                    };
                    # send 'seal' notification
                    $ipmsg->send($message_ref);
                }
                my $key  = $m->key;
                my $body = $self->to_utf8( $m->get_message );
                # overwrite $m for nickname
                if ( exists $ipmsg->user->{$key} ) {
                    $m = $ipmsg->user->{$key};
                }
                $self->add_message_log( 'from', $body, $m );
                $self->set_icon('ipmsg') unless @{ $ipmsg->message };
            }
            $button->set_sensitive(FALSE)
                unless $self->has_message_from_user($user);
        }
    );

    # save open_message
    my $open_message = $self->open_message;
    $open_message->{ $user->key } = $button;
    $self->open_message($open_message);
    return $button;
}

sub has_message_from_user {
    my( $self, $user ) = @_;
    my $ipmsg = $self->ipmsg;
    return unless @{ $ipmsg->message };

    my $result;
    my $i = 0;
    for my $m ( @{ $ipmsg->message } ) {
        if ( $m->key eq $user->key ) {
            $result = 1;
            last;
        }
        $i++;
    }
    return wantarray ? ( $result, $i ) : $result;
}

sub clear_message_button {
    my $self = shift;

    my $button = Gtk2::Button->new_from_stock('gtk-clear');
    $button->signal_connect(
        clicked => sub {
            my $log_buf = $self->message_log->get_buffer;
            my $start   = $log_buf->get_start_iter;
            my $end     = $log_buf->get_end_iter;
            $log_buf->delete( $start, $end );
        }
    );
    return $button;
}

1;
