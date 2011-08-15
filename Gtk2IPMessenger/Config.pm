package Gtk2IPMessenger::Config;

use warnings;
use strict;
use Sys::Hostname qw( hostname );
use Encode qw(encode);
use YAML qw( LoadFile DumpFile );

sub load_config {
    my $self = shift;

    return if $self->conf;
    my $conf;
    eval { $conf = LoadFile( $self->conf_file ); };
    if ($@) {

        # load default
        $conf->{username} = $ENV{USER} || 'gtk2ipmsg';
        $conf->{nickname} = $ENV{USER} || 'gtk2ipmsg';
        $conf->{groupname}   = '';
        $conf->{hostname}    = hostname;
        $conf->{broadcast}   = [];
        $conf->{priority}    = {};
        $conf->{notify_icon} = 0;
    }
    else {
        $conf->{groupname} = encode 'shiftjis', $conf->{groupname};
        $conf->{nickname}  = encode 'shiftjis', $conf->{nickname};
    }

    $self->conf($conf);
}

sub save_config {
    my ( $self, $new ) = @_;
    my $ipmsg = $self->ipmsg;
    my $conf  = $self->conf;

    # self information needs to be updated
    for my $key (qw( username nickname groupname hostname )) {
        if ( exists $new->{$key} ) {
            $conf->{$key} = $self->from_utf8( $new->{$key} );
            $ipmsg->$key( $conf->{$key} );
        }
    }

    # show encoding in config file
    $conf->{encoding} = $self->encoding;

    # those column are hash ref
    for my $column (qw( broadcast priority notify_icon )) {
        next unless exists $new->{$column};
        if ( 'HASH' eq ref $new->{$column} ) {
            my $hash_ref = $new->{$column};
            for my $key ( keys %{$hash_ref} ) {
                $hash_ref->{$key} = $self->from_utf8( $hash_ref->{$key} );
            }
        }
        $conf->{$column} = $new->{$column};
    }

    $self->conf($conf);
    DumpFile( $self->conf_file, $conf );
}

1;
