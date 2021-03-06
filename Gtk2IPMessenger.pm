package Gtk2IPMessenger;

use warnings;
use strict;
use Encode qw( decode encode );
use File::Spec::Functions;
use Glib qw( TRUE FALSE );
use Gtk2::Helper;
use Gtk2IPMessenger::EventHandler;
use IO::Interface::Simple;
use Net::IPMessenger::CommandLine;
use POSIX qw( strftime );
use base qw(
    Class::Accessor::Fast
    Gtk2IPMessenger::AttachFile
    Gtk2IPMessenger::Config
    Gtk2IPMessenger::ConfigWindow
    Gtk2IPMessenger::InputMessage
    Gtk2IPMessenger::ListWindow
    Gtk2IPMessenger::MessageLog
    Gtk2IPMessenger::NotifyIcon
    Gtk2IPMessenger::TrayIcon
    Gtk2IPMessenger::UserList
);
__PACKAGE__->mk_accessors(
    qw(
        ipmsg           encoding        conf            conf_file
        list_window     main_window     config_window   dl_request
        chosen_user     bubble          has_timeout     icon_image
        slist           users_label     open_message    opened_status
        message_log     input_message   send_button     notify_icon
        notify_window   incr_search     ipmsg_icon      ipmsgrev_icon
        ipmsg_anm       users_tab       tabs            expander
        attach_button   label_attach
        )
);

# this is quite private font setting
Gtk2::Rc->parse_string(<<__STYLE__);

style "osaka" {
    font_name = "Osaka-Mono 10"
}

widget "*" style "osaka"
__STYLE__

our $VERSION = '0.02';

sub new {
    my( $class, %args ) = @_;
    my $self = {};
    bless $self, $class;

    my $conf_file = catfile( $ENV{HOME}, '.gtk2ipmsgrc' );
    $self->conf_file($conf_file);
    my $conf = $self->load_config;
    $args{GroupName} = $conf->{groupname};
    $args{HostName}  = $conf->{hostname};
    $args{NickName}  = $conf->{nickname};
    $args{UserName}  = $conf->{username};

    $self->encoding( delete $args{Encoding}
            || $conf->{encoding}
            || 'shiftjis' );

    $self->tabs(       {} );
    $self->dl_request( {} );

    # setup icon path
    $self->ipmsg_icon( catfile( 'img', 'ipmsg.ico' ) );
    $self->ipmsgrev_icon( catfile( 'img', 'ipmsgrev.ico' ) );
    $self->ipmsg_anm( catfile( 'img', 'ipmsg_anm.gif' ) );

    my $ipmsg = Net::IPMessenger::CommandLine->new(%args)
        or die "cannot new Net::IPMessenger::CommandLine : $!\n";
    $self->ipmsg($ipmsg);

    my( $serveraddr, $broadcast ) = $self->get_if;
    $ipmsg->serveraddr($serveraddr);
    $ipmsg->add_broadcast($broadcast);
    $ipmsg->add_broadcast('255.255.255.255');
    for my $addr ( @{ $conf->{broadcast} } ) {
        $ipmsg->add_broadcast($addr);
    }

    # observe socket handle
    my $sock = $ipmsg->get_connection;
    Gtk2::Helper->add_watch(
        fileno $sock,
        'in',
        sub {
            $ipmsg->recv;
            return TRUE;
        },
        $sock
    );
    $self->add_events;
    $self->add_timeout_events;
    $ipmsg->join;
    $self->getlist;
    return $self;
}

sub to_utf8 {
    my( $self, $str ) = @_;
    return decode $self->encoding, $str;
}

sub from_utf8 {
    my( $self, $str ) = @_;
    return encode $self->encoding, $str;
}

sub getlist {
    my $self  = shift;
    my $conf  = $self->conf;
    my $ipmsg = $self->ipmsg;

    return unless 'ARRAY' eq ref $conf->{getlist};
    my $command = $ipmsg->messagecommand('GETLIST');
    for my $addr ( @{ $conf->{getlist} } ) {
        $ipmsg->send(
            {
                command  => $command,
                peeraddr => $addr,
                peerport => 2425,
            }
        );
    }
}

sub get_user {
    my( $self, $str ) = @_;
    my $user = $self->ipmsg->user->{$str};
    # just set chosen user as user in case user already logout
    unless ($user) {
        # hogehoge@127.0.0.1:2425';
        my( $nick, $addr, $port ) =
            ( $str =~ /(\w+)\@(\d+\.\d++\.\d+\.\d+):(\d+)/ );
        $user = Net::IPMessenger::ClientData->new(
            User     => $nick,
            Nick     => $nick,
            PeerAddr => $addr,
            PeerPort => $port,
        );
    }
}

sub get_if {
    my @interfaces = IO::Interface::Simple->interfaces;
    for my $if (@interfaces) {
        if ( not $if->is_loopback and $if->is_running and $if->is_broadcast ) {
            return ( $if->address, $if->broadcast );
        }
    }
    return;
}

sub add_events {
    my $self       = shift;
    my $ipmsg      = $self->ipmsg;
    my $ev_handler = Gtk2IPMessenger::EventHandler->new;
    # when user list is updated
    $ev_handler->add_callback(
        update_list => sub {
            $self->update_user_list;
            $self->flash_notify_icon;
        }
    );
    # when your message is opened
    $ev_handler->add_callback(
        opened => sub {
            my $user = shift;

            if ( exists $ipmsg->user->{ $user->key } ) {
                $user = $ipmsg->user->{ $user->key };
            }
            my $nickname = $user->nick;
            my $status   = sprintf "Last message is opened at %s by %s",
                strftime( "%H:%M:%S", localtime ), $nickname;
            my $by = sprintf "By %s (%s/%s)",
                $user->nick, $user->group, $user->host;

            $self->opened_status->set_label( $self->to_utf8($status) );
            $self->show_bubble( "Your message has opened",
                $self->to_utf8($by) );
        }
    );
    # when you get new message
    $ev_handler->add_callback(
        get_message => sub {
            my $user = shift;
            my $key  = $user->key;
            # activate open button
            my $open_message = $self->open_message;
            if ( exists $open_message->{$key} ) {
                $open_message->{$key}->set_sensitive(TRUE);
            }
            # change icon
            $self->set_icon('ipmsgrev');
            # show notify
            my @message = $self->generate_header($user);
            $self->show_bubble(@message);
            # hilight tab
            $self->hilight_tab($user);

            if ( $user->attach ) {
                $self->read_attach_file($user);
                $self->hide_progress_bar($user);
            }
            return TRUE;
        }
    );
    $ipmsg->add_event_handler($ev_handler);
}

# add default timeout events
sub add_timeout_events {
    my $self = shift;

    # default timeout event
    Glib::Timeout->add(
        # 1000 = 1sec
        60000,
        sub {
            my $count = @{ $self->ipmsg->message };
            if ($count) {
                my $message = $count == 1 ? 'message' : 'messages';
                $self->show_bubble( "Message reminder",
                    "$count $message left" );
            }
            return TRUE;
        }
    );
}

sub alert_message {
    my( $self, $text ) = @_;

    my $parent = $self->main_window;
    my $icon   = 'warning';

    my $dialog =
        Gtk2::MessageDialog->new_with_markup( $parent,
        [qw/modal destroy-with-parent/],
        $icon, 'ok', sprintf "$text" );

    $dialog->run;
    $dialog->destroy;
}

sub generate_header {
    my( $self, $user ) = @_;

    # get first line of message
    my $body = ( split /\n/, $user->get_message )[0];
    my $nickname = $self->get_nickname($user);

    my $info = sprintf "From: %s\nDate: %s",
        $self->to_utf8($nickname), $user->time;
    return ( $self->to_utf8($body), $info );
}

sub get_nickname {
    my( $self, $user ) = @_;
    my $ipmsg = $self->ipmsg;
    my $key   = $user->key;

    my $nickname =
        exists $ipmsg->user->{$key}
        ? $ipmsg->user->{$key}->nickname
        : $user->nickname;
    return $nickname;
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

sub send_READMSG {
    my( $self, $user ) = @_;
    my $ipmsg = $self->ipmsg;
    my $ref   = {
        command  => $ipmsg->messagecommand('READMSG'),
        peeraddr => $user->peeraddr,
        peerport => $user->peerport,
    };
    # send 'seal' notification
    $ipmsg->send($ref);
}

sub send_GETFILEDAT {
    my( $self, $ref, $user ) = @_;
    my $ipmsg    = $self->ipmsg;
    my $fileid   = $ref->{fileid};
    my $packetid = sprintf "%x", $user->packet_num;

    my $command = $ipmsg->messagecommand('GETFILEDAT');
    my $option  = sprintf( "%s:%s:%s:", $packetid, hex($fileid), 0 );
    my $getfiledata = {
        command  => $command,
        option   => $option,
    };
    return $ipmsg->generate_packet($getfiledata);
}

sub find_widget {
    my( $self, $widget, $package ) = @_;
    return unless $widget;
    my @list = ();
    for my $child ( $widget->get_children ) {
        if ( $package eq ref $child ) {
            push @list, $child;
        }
        elsif ( $child->can('get_children') ) {
            my @result = $self->find_widget( $child, $package );
            push @list, $_ for @result;
        }
    }
    return @list;
}

sub find_by_key {
    my( $self, $key, $package, $idx ) = @_;
    my $widget = $self->tabs->{$key}->{widget};
    my @list = $self->find_widget( $widget, $package );
    return $list[$idx];
}

1;
