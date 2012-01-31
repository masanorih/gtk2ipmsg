package Gtk2IPMessenger::AttachFile;

use warnings;
use strict;
use Glib qw( TRUE FALSE );
use File::Basename qw(basename);

sub read_attach_file {
    my( $self, $user ) = @_;
    my $attach = $user->attach;

    my( $fileid, $filename, $size, $mtime, $attr ) = split /:/, $attach;
    $size  = hex $size;
    $mtime = hex $mtime;

    $self->dl_request->{ $user->key } = {
        fileid   => $fileid,
        filename => $filename,
        size     => $size,
        mtime    => $mtime,
    };
}

sub new_read_progress_bar {
    my( $self, $user ) = @_;
    my $pbar = Gtk2::ProgressBar->new;
    $self->show_read_pbar( $pbar, $user );
    return $pbar;
}

sub show_read_pbar {
    my( $self, $pbar, $user ) = @_;
    return unless defined $pbar;
    my $text = $self->dl_request->{ $user->key }->{filename};
    if ($text) {
        $pbar->set_text($text);
        $pbar->show;
    }
}

our $attach_dir = $ENV{HOME};

sub new_start_download {
    my( $self, $user ) = @_;
    my $button = Gtk2::Button->new('download');
    my $key    = $user->key;
    my $dl_req = $self->dl_request;
    $button->signal_connect(
        clicked => sub {
            my $ref    = $dl_req->{$key};
            my $dialog = Gtk2::FileChooserDialog->new(
                'save', undef,
                'save',
                'gtk-cancel' => 'cancel',
                'gtk-ok'     => 'ok'
            );
            $dialog->set_current_folder($attach_dir);
            # XXX this doesn't work
            # $dialog->set_filename( $ref->{filename} );
            my $file;
            if ( 'ok' eq $dialog->run ) {
                $attach_dir = $dialog->get_current_folder;
                $file       = $dialog->get_filename;
            }
            $dialog->destroy;
            $self->get_uploaded( $ref, $user, $file ) if $file;
        }
    );
    return $button;
}

sub get_uploaded {
    my( $self, $ref, $user, $savefile ) = @_;
    my $sock = IO::Socket::INET->new(
        PeerAddr => $user->peeraddr,
        PeerPort => $user->peerport,
        Proto    => 'tcp',
    );
    die "failed to connect : $!" unless $sock;

    open my $out, '>', $savefile or die "failed to open savefile : $!";

    my $getfiledat = $self->send_GETFILEDAT( $ref, $user );
    my $wrote = $sock->syswrite($getfiledat);
    $sock->blocking(0);

    my $total    = 0;
    my $size     = $ref->{size};
    my $filename = sprintf "%s saving as %s", $ref->{filename},
        basename($savefile);
    my $readsize = $self->get_readsize($size);
    my $watcher  = Gtk2::Helper->add_watch(
        fileno $sock,
        'in',
        sub {
            my( undef, $cond, $sock ) = @_;
            # XXX need to parse request
            my $read = $sock->sysread( my $buf, $readsize );
            if ( not defined $read ) {
                warn "failed sysread while reading $filename : $!";
                return FALSE;
            }
            if ( 0 == $read ) {
                $self->remove_watch( 'watcher_download', $sock, $out );
                delete $self->dl_request->{ $user->key };
                return FALSE;
            }
            else {
                $total += $read;
                my $pbar =
                    $self->find_by_key( $user->key, 'Gtk2::ProgressBar', 0 );
                my $perc =
                    $self->update_progress( $pbar, $total, $size, $filename );
                $out->syswrite($buf);
# XXX I need to close connect when $perc = 1 because dl finished
            }
            return TRUE;
        },
        $sock
    );
    $self->{watcher_download} = $watcher;
}

sub add_attach {
    my( $self, $path, $user ) = @_;
    my $ipmsg = $self->ipmsg;

    open my $fh, '<', $path or return;
    my $fileid = fileno $fh;
    close $fh or return;

    my @stat  = stat $path;
    my $size  = sprintf "%x", $stat[7];
    my $mtime = sprintf "%x", $stat[9];

    # XXX I do not know what is "extend-attr"
    my $attr = 1;
    # XXX need to escape ':' in a filename
    # XXX check if filename is multibytes
    my $filename = basename $path;
    my $fileopt  = "\0" . sprintf "%s:%s:%s:%s:%s",
        $fileid, $filename, $size, $mtime, $attr;

    warn "fileid = $fileid";
    my $receiver = new_file_receiver();
    my $watcher  = Gtk2::Helper->add_watch(
        fileno $receiver,
        'in',
        sub {
            my( undef, $cond, $recv ) = @_;
            my $sock = $recv->accept;
            # XXX need to parse request
            my $result = $sock->sysread( my $buf, 65535 );
            if ( 0 == $result ) {
                $self->remove_watch( 'watcher', $recv );
                return FALSE;
            }
            else {
                my $by = sprintf "To: %s (%s/%s)",
                    $user->nick, $user->group, $user->host;
                $self->show_bubble( "Uploading starts", $self->to_utf8($by) );
                my $result =
                    $self->upload_file( $sock, $receiver, $path, $user,
                    $stat[7] );
            }
            return TRUE;
        },
        $receiver
    );
    $self->{watcher} = $watcher;
    return $fileopt;
}

sub upload_file {
    my( $self, $sock, $receiver, $path, $user, $size ) = @_;
    open my $fh, '<', $path or return;
    my $filename = basename $path;

    my $pbar     = $self->find_by_key( $user->key, 'Gtk2::ProgressBar', 1 );
    my $readsize = $self->get_readsize($size);
    my $total    = 0;
    $fh->blocking(0);
    my $ref = {
        sock => $sock,
        fh   => $fh,
    };
    my $timer = Glib::Timeout->add(
        1000,
        sub {
            my $ref  = shift;
            my $sock = $ref->{sock};
            my $fh   = $ref->{fh};

            my $read = $fh->sysread( my $buf, $readsize );
            if ( not defined $read ) {
                die $!;
            }
            if ( 0 == $read ) {
                $fh->close   or die $!;
                $sock->close or die $!;
                $self->remove_watch( 'watcher', $receiver );

                my $by = sprintf "To: %s (%s/%s)",
                    $user->nick, $user->group, $user->host;
                $self->show_bubble( "Uploading finished", $self->to_utf8($by) );

                return FALSE;
            }
            my $wrote = $sock->syswrite($buf);
            die $! unless defined $wrote;

            $total += $wrote;
            $self->update_progress( $pbar, $total, $size, $filename );
            return TRUE;
        },
        $ref,
    );
    return 1;
}

sub update_progress {
    my( $self, $pbar, $total, $size, $filename ) = @_;
    my $perc = $total / $size;
    $perc = 1 if $perc > 1;
    my $text = sprintf "%s (%2d%%)", $filename, $perc * 100;

    $pbar->set_fraction($perc);
    $pbar->set_text($text);
    return $perc;
}

sub hide_progress_bar {
    my( $self, $user, $widget ) = @_;
    warn "hide_progress_bar";

    $widget = $self->tabs->{ $user->key }->{widget} unless $widget;
    my @pbar = $self->find_widget( $widget, 'Gtk2::ProgressBar' );
    for my $p (@pbar) {
        $p->get_text ? $p->show : $p->hide;
        #       $p->hide unless $p->get_text;
    }

    my $download = $pbar[0];
    my $upload   = $pbar[1];
    if ( defined $user and $user->attach ) {
        $self->show_read_pbar( $download, $user );
    }
    my @button = $self->find_widget( $widget, 'Gtk2::Button' );
    for my $b (@button) {
        if ( 'download' eq $b->get_label ) {
            $download->get_text ? $b->show : $b->hide;
        }
    }

}

sub get_readsize {
    my( $self, $size ) = @_;
    my $readsize = 65535;
    while (1) {
        $size = int( $size / 1024 );
        if ( $size > 1024 ) {
            $readsize *= 100;
        }
        else {
            return $readsize;
        }
    }
}

sub new_progress_bar {
    my( $self, $name ) = @_;
    my $pbar = Gtk2::ProgressBar->new;

    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->add( Gtk2::Label->new(" ") );
    $hbox->add($pbar);
    return $hbox;
}

sub remove_watch {
    my( $self, $name, @handles ) = @_;
    my $watch = delete $self->{$name};
    Gtk2::Helper->remove_watch($watch);
    for my $fh (@handles) {
        $fh->close or die " failed to close : $!";
        undef $fh;
    }
}

sub new_file_receiver {
    # XXX localport MUST not be hard coded
    my $sock = IO::Socket::INET->new(
        Listen    => 1,
        Reuse     => 1,
        Proto     => 'tcp',
        LocalPort => 2425,
    ) or warn "failed to open socket : $!";
    return $sock;
}

1;
