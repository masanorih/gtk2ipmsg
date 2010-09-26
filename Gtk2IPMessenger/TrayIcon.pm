package Gtk2IPMessenger::TrayIcon;

use warnings;
use strict;
use File::Spec::Functions;
use FindBin qw($Bin);
use Glib qw( TRUE FALSE );
use Gtk2::Notify -init, 'ipmsg';
use Gtk2::TrayIcon;

my $icon_size        = 'small-toolbar';
my $show_bubble_time = 5000;

sub new_tray_icon {
    my $self = shift;

    $self->create_stock_item;

    my $eventbox = Gtk2::EventBox->new;
    my $img = Gtk2::Image->new_from_stock( 'ipmsg', $icon_size );
    $eventbox->add($img);

    my $icon = Gtk2::TrayIcon->new('ipmsg');
    $icon->add($eventbox);
    $icon->show_all;

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

    # save items
    $self->icon_image($img);
    return $icon;
}

sub show_bubble {
    my( $self, $header, $message ) = @_;

    my $icon   = catfile( $Bin , $self->ipmsg_icon );
    my $notify = Gtk2::Notify->new( $header, $message, $icon );
    $notify->set_timeout($show_bubble_time);
    $notify->show;
}

sub set_icon {
    my( $self, $stock_id ) = @_;

    if ( $stock_id eq 'ipmsgrev' ) {
        # do nothing when timeout event is already set
        return if $self->has_timeout;
        # animate tray icon
        Glib::Timeout->add(
            1000,
            sub {
                # finish animate when all messages have been read
                unless ( @{ $self->ipmsg->message } ) {
                    $self->has_timeout(undef);
                    return FALSE;
                }
                # get present stock_id, size
                my( $stock_id, $icon_size ) = $self->icon_image->get_stock;
                # change image
                $stock_id = $stock_id eq 'ipmsgrev' ? 'ipmsg' : 'ipmsgrev';
                $self->icon_image->set_from_stock( $stock_id, $icon_size );
                $self->has_timeout(1);
                return TRUE;
            }
        );
        # animate notify window icon if exists
        $self->animate_notify_icon;
    }
    else {
        $self->icon_image->set_from_stock( $stock_id, $icon_size );
    }
}

sub create_stock_item {
    my $self = shift;

    my $icon_factory = Gtk2::IconFactory->new;

    for my $stock_id (qw( ipmsg ipmsgrev )) {
        Gtk2::Stock->add(
            {
                stock_id           => $stock_id,
                label              => 'IP Messenger',
                modifier           => [],
                translation_domain => 'gtk2_image',
            }
        );
        my $icon_method = $stock_id . '_icon';
        my $icon = $self->$icon_method;
        my $icon_set =
            Gtk2::IconSet->new_from_pixbuf(
            Gtk2::Gdk::Pixbuf->new_from_file($icon) );
        $icon_factory->add( $stock_id, $icon_set );
    }
    $icon_factory->add_default;
}

sub tray_context_menu {
    my $self  = shift;
    my $menu  = Gtk2::Menu->new;
    my $ipmsg = $self->ipmsg;

    # show quick message list
    if ( @{ $ipmsg->message } ) {
        my $quick = Gtk2::Menu->new;
        for my $user ( @{ $ipmsg->message } ) {
            my $message = $self->generate_header($user);
            my $item    = Gtk2::MenuItem->new($message);
            $quick->append($item);
            $quick->append( Gtk2::TearoffMenuItem->new );
        }
        my $item = Gtk2::MenuItem->new('quick list');
        $item->set_submenu($quick);

        $menu->append($item);
        $menu->append( Gtk2::TearoffMenuItem->new );
    }

    # open user list
    my $item_open = Gtk2::ImageMenuItem->new('open user list');
    my $img = Gtk2::Image->new_from_stock( 'ipmsg', $icon_size );
    $item_open->set_image($img);

    my $item_config =
        Gtk2::ImageMenuItem->new_from_stock( 'gtk-preferences', undef );
    my $item_quit = Gtk2::ImageMenuItem->new_from_stock( 'gtk-quit', undef );

    $item_open->signal_connect(
        activate => sub {
            $self->new_list_window;
        }
    );
    $item_config->signal_connect(
        activate => sub {
            $self->new_config_window;
        }
    );
    $item_quit->signal_connect(
        activate => sub {
            $self->ipmsg->quit;
            Gtk2->main_quit;
        }
    );

    $menu->append($item_open);
    $menu->append( $self->context_item_notify_icon );
    $menu->append($item_config);
    $menu->append( Gtk2::TearoffMenuItem->new );
    $menu->append($item_quit);
    $menu->show_all;
    return $menu;
}

# returns 'show notify icon' context menu
sub context_item_notify_icon {
    my $self = shift;

    my $menu_type   = $self->notify_icon ? 'close' : 'open';
    my $menu_name   = $menu_type . ' notify icon';
    my $notify_icon = Gtk2::ImageMenuItem->new($menu_name);
    $notify_icon->signal_connect(
        activate => sub {
            $menu_type eq 'close'
                ? $self->close_notify_icon
                : $self->new_notify_icon;
        }
    );
    return $notify_icon;
}

1;
