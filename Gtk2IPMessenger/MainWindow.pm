package Gtk2IPMessenger::MainWindow;

use warnings;
use strict;
use Glib qw( TRUE FALSE );

sub new_main_window {
    my $self = shift;

    if ( $self->main_window ) {
        return;
    }

    my $window = Gtk2::Window->new('toplevel');
    $window->set_title('Gtk2 IP Messenger');
    # save main_window
    $self->main_window($window);

    $window->signal_connect(
        delete_event => sub {
            $self->main_window(undef);
        }
    );
    $window->set_border_width(5);
    $window->set_icon_from_file('ipmsg.ico');
    $window->add( $self->new_vbox() );
    $window->show_all;
}

sub new_vbox {
    my $self = shift;

    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->pack_start( $self->users_frame,         TRUE, TRUE, 0 );
    $vbox->pack_start( $self->message_log_frame,   TRUE, TRUE, 0 );
    $vbox->pack_start( $self->input_message_frame, TRUE, TRUE, 0 );
    $vbox->show_all();
    return $vbox;
}

sub users_frame {
    my $self = shift;

    my $frame = Gtk2::Frame->new("User List");
    $frame->set_border_width(5);

    my $label = Gtk2::Label->new;
    # save users_label
    $self->users_label($label);

    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_shadow_type('etched-out');
    $scrolled->set_policy( 'automatic', 'automatic' );
    $scrolled->set_border_width(5);
    $scrolled->set_size_request( 450, 150 );
    $scrolled->add( $self->new_user_list );

    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->pack_start( $label, FALSE, FALSE, 0 );
    $hbox->pack_end( $self->join_button, FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->add($scrolled);
    $vbox->add($hbox);

    $frame->add($vbox);
    return $frame;
}

sub message_log_frame {
    my $self = shift;

    # Generate ScrolledWindow
    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_shadow_type('etched-out');
    $scrolled->set_policy( 'automatic', 'automatic' );
    $scrolled->set_size_request( 300, 200 );
    $scrolled->set_border_width(5);

    # message log textview
    $scrolled->add( $self->new_message_log );

    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->pack_end( $self->clear_message_button, FALSE, FALSE, 0 );
    $hbox->pack_end( $self->open_message_button,  FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->add($hbox);
    $vbox->add($scrolled);

    my $frame = Gtk2::Frame->new("Message Log");
    $frame->set_border_width(5);
    $frame->add($vbox);

    return $frame;
}

sub input_message_frame {
    my $self = shift;

    my $frame = Gtk2::Frame->new("Input Message Buffer");
    $frame->set_border_width(1);

    #
    # Generate ScrolledWindow
    #
    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_shadow_type('etched-out');
    $scrolled->set_policy( 'automatic', 'automatic' );
    $scrolled->set_size_request( 300, 100 );
    # method of Gtk2::Container
    $scrolled->set_border_width(5);

    $scrolled->add( $self->new_input_message );

    my $label = Gtk2::Label->new;
    $self->opened_status($label);
    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->add($label);
    $hbox->pack_end( $self->new_send_button, FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->add($scrolled);
    $vbox->add($hbox);

    $frame->add($vbox);
    return $frame;
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


1;
