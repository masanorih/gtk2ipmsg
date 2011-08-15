package Gtk2IPMessenger::ConfigWindow;

use warnings;
use strict;
use Glib qw( TRUE FALSE );
use Gtk2::Gdk::Keysyms;

sub new_config_window {
    my $self = shift;

    if ( $self->config_window ) {
        return;
    }

    my $window = Gtk2::Window->new('toplevel');
    $window->set_title('Gtk2 IP Messenger config');
    $window->set_position('center_always');
    $window->set_border_width(5);

    # save config_window
    $self->config_window($window);
    $window->signal_connect(
        delete_event => sub {
            $self->config_window(undef);
        }
    );

    my $conf = $self->conf;

    my $label_nick = Gtk2::Label->new('nickname');
    my $entry_nick = Gtk2::Entry->new;
    $entry_nick->set_text( $self->to_utf8( $conf->{nickname} ) );

    my $label_group = Gtk2::Label->new('groupname');
    my $entry_group = Gtk2::Entry->new;
    $entry_group->set_text( $self->to_utf8( $conf->{groupname} ) );

    my $label_nicon = Gtk2::Label->new('show notify icon on start up');
    my $entry_nicon = Gtk2::CheckButton->new;
    $entry_nicon->set_active( $conf->{notify_icon} );

    my $table = Gtk2::Table->new( 3, 5, FALSE );
    $table->set_row_spacings(3);
    $table->set_col_spacings(3);
    $table->attach_defaults( $label_nick,  0, 1, 0, 1 );
    $table->attach_defaults( $entry_nick,  1, 2, 0, 1 );
    $table->attach_defaults( $label_group, 0, 1, 1, 3 );
    $table->attach_defaults( $entry_group, 1, 2, 1, 3 );
    $table->attach_defaults( $label_nicon, 0, 1, 3, 5 );
    $table->attach_defaults( $entry_nicon, 1, 2, 3, 5 );

    my $button_cancel = Gtk2::Button->new_from_stock('gtk-cancel');
    my $button_ok     = Gtk2::Button->new_from_stock('gtk-ok');

    my ( $broadcast_frame, $broadcast_list ) = $self->new_broadcast_frame;

    my $hbox = Gtk2::HBox->new;
    $hbox->pack_end( $button_ok,     FALSE, FALSE, 0 );
    $hbox->pack_end( $button_cancel, FALSE, FALSE, 0 );

    my $vbox = Gtk2::VBox->new;
    $vbox->add($table);
    $vbox->add($broadcast_frame);
    $vbox->add($hbox);

    $window->add($vbox);
    $window->show_all;

    $button_cancel->signal_connect(
        clicked => sub {
            $self->config_window(undef);
            $window->destroy;
        }
    );
    $button_ok->signal_connect(
        clicked => sub {
            my $nick  = $entry_nick->get_text;
            my $group = $entry_group->get_text;
            my $nicon = $entry_nicon->get_active;
            my $broadcast;
            for my $ref ( @{ $broadcast_list->{data} } ) {
                push @{$broadcast}, $ref->[0];
            }

            $self->save_config(
                {
                    nickname    => $nick,
                    groupname   => $group,
                    broadcast   => $broadcast,
                    notify_icon => $nicon,
                }
            );
            $self->config_window(undef);
            $window->destroy;
        }
    );

    return $window;
}

sub new_broadcast_frame {
    my $self = shift;

    my $frame = Gtk2::Frame->new("Additional broadcast IP address");
    $frame->set_border_width(5);

    my $slist = Gtk2::SimpleList->new( addr => 'text' );
    $slist->set_size_request( 150, 100 );
    my $conf = $self->conf;
    for my $addr ( @{ $conf->{broadcast} } ) {
        push @{ $slist->{data} }, $addr;
    }

    my $label_example   = Gtk2::Label->new("example:192.168.1.255\n(or FQDN)");
    my $entry_broadcast = Gtk2::Entry->new;
    my $button_append   = Gtk2::Button->new('>>');
    my $button_delete   = Gtk2::Button->new('<<');

    $entry_broadcast->signal_connect(
        key_press_event => sub {
            my ( $widget, $event ) = @_;
            if ( $event->keyval == $Gtk2::Gdk::Keysyms{Return} ) {
                $button_append->clicked;
                return TRUE;
            }
        }
    );
    $button_append->signal_connect(
        clicked => sub {
            my $addr = $entry_broadcast->get_text;
            $entry_broadcast->set_text("");
            return unless $addr;

            if ( $addr =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/o ) {
                push @{ $slist->{data} }, $addr;
            }
            elsif ( gethostbyname $addr ) {
                my $ip = join '.',
                  map { ord $_ } unpack( "aaaa", gethostbyname $addr );
                push @{ $slist->{data} }, $ip;
            }
        }
    );
    $button_delete->signal_connect(
        clicked => sub {
            my $tpath = $slist->get_selection->get_selected_rows;
            return unless defined $tpath;
            my $ref = $slist->get_row_data_from_path($tpath);
            return unless defined $ref;

            my $i = 0;
            for my $data ( @{ $slist->{data} } ) {
                if ( $ref->[0] eq $data->[0] ) {
                    splice @{ $slist->{data} }, $i, 1;
                    last;
                }
                $i++;
            }
        }
    );

    my $scrolled = Gtk2::ScrolledWindow->new( undef, undef );
    $scrolled->set_shadow_type('etched-out');
    $scrolled->set_policy( 'automatic', 'automatic' );
    $scrolled->set_border_width(5);
    $scrolled->add($slist);

    my $vbox1 = Gtk2::VBox->new;
    $vbox1->add($label_example);
    $vbox1->add($entry_broadcast);
    $vbox1->add( Gtk2::Label->new );

    my $vbox2 = Gtk2::VBox->new;
    $vbox2->add( Gtk2::Label->new );
    $vbox2->add($button_append);
    $vbox2->add($button_delete);
    $vbox2->add( Gtk2::Label->new );

    my $hbox = Gtk2::HBox->new;
    $hbox->add($vbox1);
    $hbox->add($vbox2);
    $hbox->add($scrolled);

    $frame->add($hbox);
    return ( $frame, $slist );
}

1;
