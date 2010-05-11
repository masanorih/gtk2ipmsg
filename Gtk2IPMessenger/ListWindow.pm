package Gtk2IPMessenger::ListWindow;

use warnings;
use strict;
use Glib qw( TRUE FALSE );
use Gtk2::Gdk::Keysyms;

sub new_list_window {
    my $self = shift;

    # list_window is opening
    return if $self->list_window;

    my $window = Gtk2::Window->new('toplevel');
    $window->set_title('Gtk2 IP Messenger User List');
    $window->set_border_width(5);
    $window->set_icon_from_file('ipmsg.ico');
    # save list_window
    $self->list_window($window);
    $window->signal_connect(
        delete_event => sub { $self->list_window(undef) }
    );

    $window->add( $self->users_vbox );
    $window->show_all;
}

sub users_vbox {
    my $self = shift;

    my $label = Gtk2::Label->new;
    # save users_label
    $self->users_label($label);

    # scrolled list
    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_shadow_type('etched-out');
    $scrolled->set_policy( 'automatic', 'automatic' );
    $scrolled->set_border_width(5);
    $scrolled->set_size_request( 600, 200 );
    $scrolled->add( $self->new_user_list );

    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->pack_start( $label, FALSE, FALSE, 0 );
    $hbox->pack_end( $self->join_button, FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->pack_start( $self->user_incr_search_text, FALSE, FALSE, 0 );
    $vbox->add($scrolled);
    $vbox->pack_start( $hbox, FALSE, FALSE, 0 );
    return $vbox;
}

sub join_button {
    my $self = shift;

    my $button = Gtk2::Button->new_from_stock('gtk-refresh');
    $button->signal_connect(
        clicked => sub {
            $self->ipmsg->join;
            $self->getlist;
        }
    );
    return $button;
}

sub user_incr_search_text {
    my $self = shift;

    # incremental search text
    my $incr_search = Gtk2::Entry->new;
    $incr_search->signal_connect(
        key_release_event => sub {
            my( $widget, $event ) = @_;
            my $buf = $incr_search->get_text;
            $self->incr_search($buf);
            $self->update_user_list;
            if ( $event->keyval == $Gtk2::Gdk::Keysyms{Return} ) {
                # open message window if list shows one user
                if ( $#{ $self->slist->{data} } == 0 ) {
                    $self->slist->select(0);
                    $self->new_message_window;
                }
            }
        }
    );

    my $label = Gtk2::Label->new("search:");
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->pack_start( $label, FALSE, TRUE, 0 );
    $hbox->pack_end( $incr_search, TRUE, TRUE, 0 );
    return $hbox;
}

1;
