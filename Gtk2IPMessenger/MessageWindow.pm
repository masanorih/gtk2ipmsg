package Gtk2IPMessenger::MessageWindow;

use warnings;
use strict;
use Glib qw( TRUE FALSE );

sub new_message_window {
    my( $self, $chosen_user ) = @_;
    $chosen_user ||= $self->chosen_user;

    my $user = $self->ipmsg->user->{$chosen_user};

    # message_window is already opening
    return if $self->message_window->{$chosen_user};

    # just set chosen user as user in case user already logout
    unless ($user) {
        # haram@203.181.79.112:2425';
        my( $nick, $addr, $port ) =
            ( $chosen_user =~ /(\w+)\@(\d+\.\d++\.\d+\.\d+):(\d+)/ );
        $user = Net::IPMessenger::ClientData->new(
            User     => $nick,
            Nick     => $nick,
            PeerAddr => $addr,
            PeerPort => $port,
        );
    }

    my $window = Gtk2::Window->new('toplevel');
    $window->set_title('Gtk2 IP Messenger MessageBox');
    # save message_window
    my $message_window = $self->message_window;
    $message_window->{$chosen_user} = $window;
    $window->signal_connect(
        delete_event => sub {
            delete $message_window->{$chosen_user};
        }
    );

    $window->set_border_width(5);
    $window->set_icon_from_file( $self->ipmsg_icon );
    $window->add( $self->new_vbox($user) );
    $window->show_all;
}

sub new_vbox {
    my( $self, $user ) = @_;

    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->pack_start( $self->message_log_frame($user),   TRUE, TRUE, 0 );
    $vbox->pack_start( $self->input_message_frame($user), TRUE, TRUE, 0 );
    $vbox->show_all();
    return $vbox;
}

sub message_log_frame {
    my( $self, $user ) = @_;

    # Generate ScrolledWindow
    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_shadow_type('etched-out');
    $scrolled->set_policy( 'automatic', 'automatic' );
    $scrolled->set_size_request( 550, 300 );
    $scrolled->set_border_width(5);

    # message log textview
    $scrolled->add( $self->new_message_log($user) );

    my $label = Gtk2::Label->new;
    $label->set_label( $self->to_utf8( $user->nickname ) );

    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->add($label);
    $hbox->pack_end( $self->clear_message_button, FALSE, FALSE, 0 );
    $hbox->pack_end( $self->open_message_button($user),  FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->pack_start( $hbox, FALSE, FALSE, 0 );
    $vbox->add($scrolled);

    my $frame = Gtk2::Frame->new("Message Log");
    $frame->set_border_width(5);
    $frame->add($vbox);

    return $frame;
}

sub input_message_frame {
    my( $self, $user ) = @_;

    my $frame = Gtk2::Frame->new("Input Message Buffer");
    $frame->set_border_width(1);

    #
    # Generate ScrolledWindow
    #
    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_shadow_type('etched-out');
    $scrolled->set_policy( 'automatic', 'automatic' );
    $scrolled->set_size_request( 500, 100 );
    # method of Gtk2::Container
    $scrolled->set_border_width(5);

    $scrolled->add( $self->new_input_message );

    my $label = Gtk2::Label->new;
    $self->opened_status($label);
    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->add($label);
    $hbox->pack_end( $self->new_send_button($user), FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->add($scrolled);
    $vbox->pack_start( $hbox, FALSE, FALSE, 0 );

    $frame->add($vbox);
    return $frame;
}

1;
