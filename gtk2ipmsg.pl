#!/usr/bin/perl
#
# This is gtk2-perl based IP Messenger client.
#
# - how to get this work
#
#   for Ubuntu users
#       you need to install
#       libgtk2.0-dev for Gtk2
#       libnotify-dev for Gtk2::Nofity
#
#   those Perl modules are required.
#
#       IO::Interface::Simple
#       YAML
#       Class::Accessor::Fast
#       ExtUtils::Depends
#       ExtUtils::PkgConfig
#       Gtk2
#       Gtk2::TrayIcon
#       Gtk2::Notify
#
# - for animation support
#
#       Gtk2::ImageView
#
# - for encryption support
#
#   for Ubuntu users
#       you need to install libssl-dev for Crypt::OpenSSL::RSA
#
#   those Perl modules are required.
#
#       Crypt::CBC
#       Crypt::Blowfish
#       Crypt::OpenSSL::RSA
#       Crypt::OpenSSL::Bignum
#
# - if you get troubled with text input through IM
#
#       export GTK_IM_MODULE="scim" # or an IM which you use
#       might help you.
#
# hope you luck and enjoy.
#
use warnings;
use strict;
use lib qw(.);
use Gtk2IPMessenger;
use Gtk2 -init;

my $gipmsg = Gtk2IPMessenger->new;
$gipmsg->new_tray_icon;

Gtk2->main;
