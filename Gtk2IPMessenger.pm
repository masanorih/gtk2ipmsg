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
    Gtk2IPMessenger::Config
    Gtk2IPMessenger::ConfigWindow
    Gtk2IPMessenger::InputMessage
    Gtk2IPMessenger::ListWindow
    Gtk2IPMessenger::MessageWindow
    Gtk2IPMessenger::MainWindow
    Gtk2IPMessenger::MessageLog
    Gtk2IPMessenger::NotifyIcon
    Gtk2IPMessenger::TrayIcon
    Gtk2IPMessenger::UserList
);
__PACKAGE__->mk_accessors(
    qw(
        ipmsg           encoding        conf            conf_file
        list_window     message_window  main_window     config_window
        chosen_user     bubble          has_timeout     icon_image
        slist           users_label     open_message    opened_status
        message_log     input_message   send_button     notify_icon
        notify_window   incr_search     ipmsg_icon      ipmsgrev_icon
        ipmsg_anm
        )
);

Gtk2::Rc->parse_string(<<__STYLE__);

style "osaka" {
    font_name = "Osaka-Mono 10"
}

widget "*" style "osaka"
__STYLE__

our $VERSION = '0.02';

sub new {
    my( $class, %args ) = @_;
    my $self  = {};
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

    $self->message_window({});

    # setup icon path
    $self->ipmsg_icon( catfile( 'img', 'ipmsg.ico' ) );
    $self->ipmsgrev_icon( catfile( 'img', 'ipmsgrev.ico') );
    $self->ipmsg_anm( catfile( 'img', 'ipmsg_anm.gif') );

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
            my $status = sprintf "Last message is opened at %s by %s",
                strftime( "%H:%M:%S", localtime ), $nickname;
            my $by = sprintf "By %s (%s/%s)",
                $user->nick, $user->group, $user->host;

            $self->opened_status->set_label( $self->to_utf8($status) );
            $self->show_bubble( "Your Message has opened",
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

            $self->set_icon('ipmsgrev');
            my @message = $self->generate_header($user);
            $self->show_bubble(@message);
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
    my $self = shift;
    my $text = shift;

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
    my $ipmsg = $self->ipmsg;

    # get first line of message
    my $body = ( split /\n/, $user->get_message )[0];
    my $key = $user->key;
    my $nickname = exists $ipmsg->user->{$key}
        ? $ipmsg->user->{$key}->nickname
        : $user->nickname;

    my $info = sprintf "From: %s\nDate: %s",
        $self->to_utf8($nickname), $user->time;
    return( $self->to_utf8($body), $info );
}

1;

__END__

Copyright (c) 2010, Masanori Hara massa.hara at gmail.com.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
