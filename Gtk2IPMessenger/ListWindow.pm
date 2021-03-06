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
    $window->set_icon_from_file( $self->ipmsg_icon );
    # save list_window
    $self->list_window($window);
    $window->signal_connect(
        delete_event => sub {
            $self->list_window(undef);
            $self->incr_search(undef);
        }
    );

    $window->add( $self->users_vbox );
    $window->show_all;
    $self->hide_progress_bar( undef, $window );
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

    # add tab
    my $notebook = Gtk2::Notebook->new;
    $notebook->set_scrollable(TRUE);
    # enable right click to change page
    $notebook->popup_enable;
    $self->users_tab($notebook);
    $self->tabs({});

    # expand tab
    my $expander = Gtk2::Expander->new_with_mnemonic('open tab');
    # open and added by default
    $expander->set_expanded(1);
    $expander->add($notebook);
    $expander->signal_connect_after(
        'activate' => sub {
            if ( $expander->get_expanded ) {
                $expander->set_label('close tab');
                $expander->add($notebook);
            }
            else {
                $expander->set_label('open tab');
                $expander->remove($notebook);
                $self->list_window->resize( 600, 200 );
            }
            return FALSE;
        }
    );
    $self->expander($expander);

    # restore tabs
    for my $m ( @{ $self->ipmsg->message } ) {
        $self->append_user_tab( $m->key );
        $self->hilight_tab($m);
    }

    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->pack_start( $label, FALSE, FALSE, 0 );
    $hbox->pack_end( $self->join_button, FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->pack_start( $self->user_incr_search_text, FALSE, FALSE, 0 );
    $vbox->add($scrolled);
    $vbox->pack_start( $hbox, FALSE, FALSE, 0 );
    $vbox->add($expander);
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
                    $self->append_user_tab;
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
