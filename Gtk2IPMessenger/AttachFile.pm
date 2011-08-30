package Gtk2IPMessenger::AttachFile;
use warnings;

use strict;
use Glib qw( TRUE FALSE );
use File::Basename qw(basename);

=pod
	�ե�����ź�աʥ�������ɵ��ġ����Τ���ˤϡ�IPMSG_SENDMSG
	�� IPMSG_FILEATTACHOPT ��Ω�Ƥ���å��������������ޤ���
	���κݡ��̾��or �Ź�˥�å�������³���ơ�'\0'��Ϥ���ǡ�
	ź�աʥ�������ɵ��ġ˥ե�����������󤷤ޤ���

	fileID:filename:size:mtime:fileattr[:extend-attr=val1
	[,val2...][:extend-attr2=...]]:\a[:]fileID...
	(�ʤ���size, mtime, fileattr �� hex ��ɽ�����ޤ���
	 filename��':'�������硢"::"�ǥ��������פ��ޤ�)

	����¦��ź�եե�������������ɤ�������硢������UDP�ݡ���
	��Ʊ���ֹ��TCP�ݡ��Ȥ��Ф��ơ�IPMSG_GETFILEDATA ���ޥ�ɤ��
	������ĥ���� packetID:fileID:offset ������ơ��ǡ��������׵�
	�ѥ��åȤ�Ф��ޤ����ʤ��٤�hex��
	ź��¦�����Υꥯ�����Ȥ�������ơ������׵����������ǧ���ȡ�
	�����̿�ϩ�˳����ե�����Υǡ�����ή���ޤ��ʥե����ޥåȤʤ���
=cut

sub add_attach {
    my( $self, $path ) = @_;
    my $ipmsg = $self->ipmsg;

    open my $fh, '<', $path or return;
    my $fileid = sprintf "%x", fileno $fh;
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

    my $receiver = new_file_receiver();
    my $watcher = Gtk2::Helper->add_watch(
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
                my $result = $self->upload_file( $sock, $receiver,
                    $path, $stat[7] );
            }
            return TRUE;
        },
        $receiver
    );
    $self->{watcher} = $watcher;
    return $fileopt;
}

sub upload_file {
    my( $self, $sock, $receiver, $path, $size ) = @_;

    open my $fh, '<', $path or return;
    my $filename = basename $path;

    my $read_size = $self->get_readsize($size);
    my $total = 0;
    $fh->blocking(0);
    my $ref = {
        sock => $sock,
        fh   => $fh,
    };
    my $timer = Glib::Timeout->add(
        100,
        sub {
            my $ref  = shift;
            my $sock = $ref->{sock};
            my $fh   = $ref->{fh};

            my $read = $fh->sysread( my $buf, $read_size );
            if ( not defined $read ) {
                die $!;
            }
            if ( 0 == $read ) {
                $fh->close   or die $!;
                $sock->close or die $!;
                $self->remove_watch( 'watcher', $receiver );
                return FALSE;
            }
            my $wrote = $sock->syswrite($buf);
            die $! unless defined $wrote;

            $total += $wrote;
            my $perc = $total / $size;
            $perc = 1 if $perc > 1;
            my $text = sprintf "%s (%2d%%)", $filename, $perc * 100;
            my $pbar = $self->{pbar};
            $pbar->set_fraction($perc);
            $pbar->set_text($text);
            
            return TRUE;
        },
        $ref,
    );
    return 1;
}

sub get_readsize {
    my( $self, $size ) = @_;
    my $read_size = 65535;
    while(1) {
        $size = int( $size / 1024 );
        if ( $size > 1024 ) {
            $read_size *= 100;
        }
        else {
            return $read_size;
        }
    }
}

sub new_progress_bar {
    my( $self, $name ) = @_;
    my $pbar = Gtk2::ProgressBar->new;
    $self->{pbar} = $pbar;

    my $hbox = Gtk2::HBox->new( FALSE, 5 );
    $hbox->add( Gtk2::Label->new(" ") );
    $hbox->add($pbar);
    return $hbox;
}

sub remove_watch {
    my( $self, $name, $fh ) = @_;
    my $watch = delete $self->{$name};
    Gtk2::Helper->remove_watch($watch);
    $fh->close or die " failed to close : $!";
    undef $fh;
    warn "remove_watch succeed";
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
