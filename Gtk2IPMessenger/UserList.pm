package Gtk2IPMessenger::UserList;

use warnings;
use strict;
use Gtk2::SimpleList;
use Glib qw( TRUE FALSE );

sub new_user_list {
    my $self = shift;

    my $slist = Gtk2::SimpleList->new(
        user     => 'text',
        nickname => 'text',
        group    => 'text',
        ip       => 'text',
        port     => 'int',
        pri      => 'int',
    );

    my @columns = $slist->get_columns;
    for ( my $i = 0; $i < @columns; $i++ ) {
        my $c = $columns[$i];
        $c->set_sort_column_id($i);
        # set ip sort function
        $slist->get_model->set_sort_func( $i, \&sort_byaddr )
            if $c->get_title eq 'ip';
    }

    # remove user, port, pri
    # XXX remove order must be high to low !!
    $slist->remove_column( $slist->get_column(5) );
    $slist->remove_column( $slist->get_column(4) );
    $slist->remove_column( $slist->get_column(0) );

    # save chosen user on changed
    $slist->get_selection->signal_connect(
        changed => sub {
            my $tselect = shift;
            my $key     = $self->get_slist_selected_key;
            return unless defined $key;
            $self->chosen_user($key);
        }
    );
    # double click event
    $slist->signal_connect(
        row_activated => sub {
            $self->append_user_tab;
        }
    );
    $slist->signal_connect(
        button_release_event => sub {
            my( $widget, $event ) = @_;
            my $button_nr = $event->button;
            # left click
            if ( 1 == $button_nr ) {
            }
            # right click
            elsif ( 3 == $button_nr ) {
                my $menu = $self->list_context_menu;
                $menu->popup( undef, undef, undef, undef, $button_nr,
                    $event->time );
            }
        }
    );

    # save slist
    $self->slist($slist);
    $self->update_user_list;
    return $slist;
}

sub append_user_tab {
    my( $self, $chosen_user ) = @_;
    $chosen_user ||= $self->chosen_user;
    my $notebook = $self->users_tab;

    $self->new_list_window unless $self->list_window;

    # open tab
    my $expander = $self->expander;
    if ( defined $expander and not $expander->get_expanded ) {
        $expander->set_expanded(1);
        $expander->set_label('close tab');
        $expander->add($notebook);
    }

    # do nothing when user tab already exists
    if ( exists $self->tabs->{$chosen_user} ) {
        return;
    }
    my $user  = $self->get_user($chosen_user);
    my $utf8  = $self->to_utf8( $user->nickname );
    my $label = Gtk2::Label->new($utf8);

    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->pack_start( $self->message_log_frame($user),   TRUE, TRUE, 0 );
    $vbox->pack_start( $self->input_message_frame($user), TRUE, TRUE, 0 );

    $notebook->append_page( $vbox, $label );
    $notebook->show_all;
    $self->{pbar}->hide;

    # save tab
    my $num = keys %{ $self->tabs };
    $self->tabs->{$chosen_user} = $num;
    $notebook->set_current_page($num);
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

    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
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

    my $label_opened = Gtk2::Label->new;
    $self->opened_status($label_opened);

    # HBox
    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->add($label_opened);
    $hbox->pack_end( $self->new_send_button($user), FALSE, FALSE, 0 );

    my $hbox2 = Gtk2::HBox->new( FALSE, 5 );
    my $label_attach = Gtk2::Label->new('add attach file');
    $self->label_attach($label_attach);

    $hbox2->pack_end( $self->new_attach_button, FALSE, FALSE, 0 );
    $hbox2->pack_end( $self->new_close_attach, FALSE, FALSE, 0 );
    $hbox2->pack_end( $label_attach, FALSE, FALSE, 0 );
    $hbox2->pack_start( $self->new_progress_bar, FALSE, FALSE, 0 );

    # VBox
    my $vbox = Gtk2::VBox->new( FALSE, 5 );
    $vbox->add($hbox2);
    $vbox->add($scrolled);
    $vbox->pack_start( $hbox, FALSE, FALSE, 0 );

    $frame->add($vbox);
    return $frame;
}

sub hilight_tab {
    my( $self, $user ) = @_;

    return unless $self->list_window;
    $self->append_user_tab( $user->key );

    my $nickname = $self->get_nickname($user);
    $self->update_tab_label( $user, "<span color='red'>$nickname</span>" );
}

sub update_tab_label {
    my( $self, $user, $str ) = @_;

    my $num      = $self->tabs->{ $user->key };
    my $notebook = $self->users_tab;
    my $page     = $notebook->get_nth_page($num);
    my $label    = Gtk2::Label->new;
    $label->set_markup( $self->to_utf8($str) );
    $notebook->set_tab_label( $page, $label );
}

sub update_user_list {
    my $self  = shift;
    my $ipmsg = $self->ipmsg;

    if ( $self->slist ) {
        @{ $self->slist->{data} } = ();
        my $pri = $self->conf->{priority};
        no warnings;
        for my $user ( sort { $pri->{ $b->key } <=> $pri->{ $a->key } }
            values %{ $ipmsg->user } )
        {
            $self->addto_slist($user);
        }
        my $users = sprintf "%d Users Online", scalar values %{ $ipmsg->user };
        $self->users_label->set_label($users);
    }
}

# add user to list data
sub addto_slist {
    my( $self, $user ) = @_;

    # incremental search
    my $nick = $self->to_utf8( $user->nick || $user->user );
    my $incr_search = $self->incr_search;
    if ($incr_search) {
        return unless $nick =~ /$incr_search/;
    }

    push @{ $self->slist->{data} },
        [
        $self->to_utf8( $user->user ),
        $nick,
        $self->to_utf8( $user->group || $user->host ),
        $user->peeraddr,
        $user->peerport,
        ];
}

# sort by ipv4 address
sub sort_byaddr {
    my( $list, @iter ) = @_;
    @iter = map { $_ = $list->get( $_, 3 ); $_ } @iter;
    return unless defined $iter[0];
    return unless defined $iter[1];
    my( $ipa1, $ipa2, $ipa3, $ipa4 ) = split( /\./, $iter[0], 4 );
    my( $ipb1, $ipb2, $ipb3, $ipb4 ) = split( /\./, $iter[1], 4 );

    return $ipa1 <=> $ipb1
        || $ipa2 <=> $ipb2
        || $ipa3 <=> $ipb3
        || $ipa4 <=> $ipb4;
}

sub list_context_menu {
    my $self = shift;
    my $menu = Gtk2::Menu->new;

    my $sort_menu = Gtk2::Menu->new;
    my $j         = 4;
    for my $i ( 1 .. 4 ) {
        my $pri = Gtk2::MenuItem->new("set priority to $i");
        my $val = $j--;
        $pri->signal_connect(
            button_release_event => sub {
                my $key = $self->get_slist_selected_key;
                return unless defined $key;

                my $priority = $self->conf->{priority};
                $priority->{$key} = $val;
                $self->save_config( { priority => $priority } );
                $menu->destroy;
            }
        );
        $sort_menu->append($pri);
    }
    $sort_menu->show_all;

    my $item_sort = Gtk2::MenuItem->new('_Sort');
    $item_sort->set_submenu($sort_menu);

    $menu->append($item_sort);
    $menu->append( Gtk2::TearoffMenuItem->new );
    $menu->show_all;
    return $menu;
}

sub get_slist_selected_key {
    my $self = shift;

    my $tselect = $self->slist->get_selection;
    my $tpath   = $tselect->get_selected_rows;
    return unless defined $tpath;
    my $slist = $tselect->get_tree_view;
    return unless defined $slist;
    my $row = $slist->get_row_data_from_path($tpath);
    return unless defined $row;
    my $key = sprintf "%s\@%s:%s", $row->[0], $row->[3], $row->[4];
    return $key;
}

1;
