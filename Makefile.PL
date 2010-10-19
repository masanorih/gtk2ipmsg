use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'gtk2ipmsg',
    AUTHOR              => 'Masanori Hara <massa.hara at gmail.com>',
    VERSION_FROM        => 'Gtk2IPMessenger.pm',
    ABSTRACT_FROM       => 'Gtk2IPMessenger.pm',
    PL_FILES            => {},
    LICENSE             => 'perl',
    PREREQ_PM => {
        'Test::More'             => 0,
        'version'                => 0,
        'Net::IPMessenger'       => 0,
        'IO::Interface::Simple'  => 0,
        'YAML'                   => 0,
        'Class::Accessor::Fast'  => 0,
        'ExtUtils::Depends'      => 0,
        'ExtUtils::PkgConfig'    => 0,
        'Gtk2'                   => 0,
        'Gtk2::TrayIcon'         => 0,
        'Gtk2::ImageView'        => 0,
        'Test::Exception'        => 0,
        'Gtk2::Notify'           => 0,
        'Crypt::CBC'             => 0,
        'Crypt::Blowfish'        => 0,
        'Crypt::OpenSSL::RSA'    => 0,
        'Crypt::OpenSSL::Bignum' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'gtk2ipmsg-*' },
);
