#!/usr/bin/perl -w
 use strict;
 use warnings;
 use POE qw(Component::IRC);
####################################################
 my $nickname = 'pre' . $$;
 my $ircname  = 'wmpre';
 my $server   = '';
 my $user         = 'rizonannounce';
 my $port         = '1111';
 my $password = '';

 my $sourcechannel = '~#pre_party';
 my $destchannel = '#addpre';
####################################################
 my $irc = POE::Component::IRC->spawn(
    nick => $nickname,
    ircname => $ircname,
    server  => $server,
        Username => $user,
        Port => $port,
    Password => $password,
    UseSSL => '1',
    Flood => '1',
 ) or die "Cant connect! $!";

 POE::Session->create(
     package_states => [
         main => [ qw(_start irc_001 irc_public) ],
     ],
     heap => { irc => $irc },
 );

 $poe_kernel->run();

 sub _start {
     my $heap = $_[HEAP];

     my $irc = $heap->{irc};

     $irc->yield( register => 'all' );
     $irc->yield( connect => { } );
     return;
 }

 sub irc_001 {
     my $sender = $_[SENDER];

     my $irc = $sender->get_heap();

     print "Connected to ", $irc->server_name(), "\n";

     # we join our channels
     $irc->yield( join => $sourcechannel );
     $irc->yield( join => $destchannel );
     return;
 }

 sub irc_public {
     my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
     my $nick = ( split /!/, $who )[0];
     my $channel = $where->[0];

         if($channel eq $sourcechannel)
                {
                $irc->yield( privmsg => $destchannel => "$what" );
}
     return;
 }
