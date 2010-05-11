package Gtk2IPMessenger::EventHandler;

use warnings;
use strict;
use base qw( Net::IPMessenger::EventHandler );

sub BR_ENTRY {
    my( $self, $ipmsg, $user ) = @_;
    &{ $self->callback('update_list') };
}

sub BR_EXIT {
    my( $self, $ipmsg, $user ) = @_;
    &{ $self->callback('update_list') };
}

sub ANSENTRY {
    my( $self, $ipmsg, $user ) = @_;
    &{ $self->callback('update_list') };
}

sub ANSLIST {
    my( $self, $ipmsg, $user ) = @_;
    &{ $self->callback('update_list') };
}

sub SENDMSG {
    my( $self, $ipmsg, $user ) = @_;
    $self->callback('get_message')->($user);
}

sub READMSG {
    my( $self, $ipmsg, $user ) = @_;
    $self->callback('opened')->($user);
}

1;
