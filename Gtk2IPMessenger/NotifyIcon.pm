package Gtk2IPMessenger::NotifyIcon;

use warnings;
use strict;
use Glib qw( TRUE FALSE );

# check if Gtk2::ImageView is installed
our $support_animation;

BEGIN {
    eval { require Gtk2::ImageView; };
    $support_animation = 1 unless $@;
}

sub close_notify_icon {
    my $self   = shift;
    my $window = $self->notify_window;
    return unless $window;
    $self->notify_icon(undef);
    $self->notify_window(undef);
    $window->destroy;
}

sub new_notify_icon {
    my $self = shift;
    return if $self->notify_icon;

    my $window = Gtk2::Window->new('popup');
    $window->set_title('Gtk2 IP Messenger notify icon');
    $window->set_border_width(0);
    $window->set_size_request( 32, 32 );
    $window->set_has_frame(0);

    # save notify_icon and its window
    my $img = Gtk2::Image->new_from_stock( 'ipmsg', 'dnd' );
    $self->notify_icon($img);
    $self->notify_window($window);

    my $eventbox = Gtk2::EventBox->new;
    $eventbox->add($img);

    # attach event to eventbox
    # copied from Gtk2IPMessenger::TrayIcon::new_tray_icon
    $eventbox->signal_connect(
        button_release_event => sub {
            my( $widget, $event ) = @_;
            my $button_nr = $event->button;
            # left click
            if ( 1 == $button_nr ) {
                my $message = $self->ipmsg->message;
                if ( @{$message} ) {
                    # open list window if you've already got message
                    $self->append_user_tab( $message->[0]->key );
                }
                else {
                    $self->new_list_window;
                }
            }
            # right click
            elsif ( 3 == $button_nr ) {
                my $menu = $self->tray_context_menu;
                $menu->popup( undef, undef, undef, undef, $button_nr,
                    $event->time );
            }
        },
    );

    $window->add($eventbox);
    $window->show_all;
}

sub animate_notify_icon {
    my $self = shift;
    my $stock_id;
    # return if notify_icon is not loaded
    my $notify_icon = $self->notify_icon or return;
    # kind of insurance
    return if $self->has_timeout;

    my $gif = $self->ipmsg_anm;
    # animate tray icon
    Glib::Timeout->add(
        1000,
        sub {
            # finish animate when all messages have been read
            unless ( @{ $self->ipmsg->message } ) {
                if ($support_animation) {
                    $notify_icon->set_from_stock( 'ipmsg', 'dnd' );
                }
                return FALSE;
            }

            if ($support_animation) {
                if ( 'animation' eq $notify_icon->get_storage_type ) {
#                   my $window = $self->notify_window;
#                   my( $x, $y ) = $window->get_position;
#                   $window->move( $x + 1, $y + 1 );
                    return TRUE;
                }
                my $pixbuf = Gtk2::Gdk::PixbufAnimation->new_from_file($gif);
                $notify_icon->set_from_animation($pixbuf);
            }
            else {
                # get present stock_id, size
                my( $stock_id, $icon_size ) = $self->icon_image->get_stock;
                # change image
                $stock_id = $stock_id eq 'ipmsgrev' ? 'ipmsgrev' : 'ipmsg';
                $notify_icon->set_from_stock( $stock_id, 'dnd' );
            }
            return TRUE;
        }
    );
}

our $flashing;
# add default timeout events
sub flash_notify_icon {
    my $self = shift;

    # return if notify_icon is not loaded
    my $notify_icon = $self->notify_icon or return;
    return if $self->has_timeout;

    # default timeout event
    Glib::Timeout->add(
        # 1000 = 1sec
        200,
        sub {
            if ($flashing) {
                $notify_icon->set_from_stock( 'ipmsg', 'dnd' );
                $flashing = 0;
                return FALSE;
            }
            else {
                $notify_icon->set_from_stock( 'ipmsgrev', 'dnd' );
                $flashing = 1;
            }
        }
    );
}

1;
