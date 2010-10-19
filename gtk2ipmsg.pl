#!/usr/bin/perl
#
# This is gtk2-perl based IP Messenger client.
#
# - how to get this work
#
#   for Ubuntu users
#
#       just run
#       % sudo sh ./install_deps_ubuntu
#       to install all liraries and Perl modules below.
#
#   other OS users, those Perl modules are required.
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
#    - for animation support
#
#      this Perl module is required.
#
#          Gtk2::ImageView
#
#    - for encryption support
#
#      those Perl modules are required.
#
#          Crypt::CBC
#          Crypt::Blowfish
#          Crypt::OpenSSL::RSA
#          Crypt::OpenSSL::Bignum
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

__END__

Copyright (c) 2010, Masanori Hara massa.hara at gmail.com.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
