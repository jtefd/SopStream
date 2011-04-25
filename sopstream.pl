#!/usr/bin/env perl

=pod

=head1 NAME

sopstream

=head1 SYNOPSIS

sopstream --start CHANNEL | --list-channels

=head1 OPTIONS

=over 8

=item B<--start CHANNEL | -s CHANNEL>

Starts streaming the given channel. The given parameter can either
be a named channel, a sop:// protocol URL or a channel number.

=item B<--list-channels | -l>

Lists all known channels.

=item B<--find-channels CHANNEL_NAME_SEARCH | -f CHANNEL_NAME_SEARCH>

List all channels matching the given search term.

=item B<--background | -b>

Runs the application in the background.

=item B<--kill | -k> 

Kills any running SopCast streams.

=item B<--help>

Show usage information (this screen).

=back

=head1 DESCRIPTION

A utility to find and start SopCast channels.

=cut

use strict;
use warnings;

use Getopt::Long;
use HTML::TreeBuilder;
use IO::Socket;
use LWP::UserAgent;
use Pod::Usage;

sub GetChannels() {
    my %channels = ();
    
    my $channel_list_source = 'http://www.livefootballtvs.com/sopcast-channel-list.html';
    
    my $ua = LWP::UserAgent->new();
    my $response = $ua->get($channel_list_source);
    
    my $html_page = HTML::TreeBuilder->new_from_content($response->decoded_content);
    
    my $html_feed_list = $html_page->look_down('_tag', 'table', 'id', 'customers');
    
    foreach my $html_row ($html_feed_list->find('tr')) {
        my @html_columns = $html_row->find('_tag', 'td');
        
        if (scalar(@html_columns) == 3) {
            my $channel_name = $html_columns[1]->as_text();
            my $channel_link = $html_columns[2]->as_text();
            
            $channels{$channel_name} = $channel_link if $channel_name =~ /\w$/;
        }
    }
    
    return %channels;
}

sub CheckPort($) {
    my ($port) = @_;
    
    my $sock = IO::Socket::INET->new(
        PeerAddr => 'localhost',
        PeerPort => $port, 
        Proto => 'tcp'
    ) or return 1;
    
    return undef;
}

sub GetPorts() {
    my $start = 1;
    
    while($start <= 9) {
        my ($local, $player) = ("890$start", "891$start");
        
        if (CheckPort($local) && CheckPort($player)) {
            return ($local, $player);
        }
        else {
            $start++;
        }
    }
    
    return undef;
}

sub StartSopCast($;$) {
	my ($broker, $background) = @_;
	
	if (my ($local_port, $player_port) = GetPorts()) {
    	my $cmd = sprintf('sp-sc %s %s %s', $broker, $local_port, $player_port);
    	
    	if ($background) {
            $cmd = sprintf('nohup %s > /dev/null 2> /dev/null &', $cmd);
        }
        
        system($cmd);
	}
}

my %opts;

GetOptions(
    \%opts,
    'list-channels|l',
    'find-channel|f=s',
    'start|s=s',
    'background|b',
    'kill|k',
    'help'
);

if ($opts{'help'} || scalar(keys %opts) == 0) {
    pod2usage( -verbose => 1, -exitval => 0 )
}

my %channels = GetChannels();

if ($opts{'list-channels'}) {
    print $_, "\n" foreach sort keys %channels;
}
elsif ($opts{'find-channel'}) {
	foreach (sort keys %channels) {
		my $find = quotemeta($opts{'find-channel'});
		
		if (/$find/i) {
			print $_, "\n";
		}
	}
}
elsif ($opts{'start'}) {
	my $sop_proto_regex = quotemeta('sop://');
	
	if ($opts{'start'} =~ /^$sop_proto_regex/) {
		StartSopCast($opts{'start'}, $opts{'background'});
	}
	elsif ($opts{'start'} =~ /^\d+$/) {
		#Construct sop:// URL
	}
    elsif (defined(my $link = $channels{$opts{'start'}})) {
    	StartSopCast($link, $opts{'background'});
    }
}
elsif ($opts{'kill'}) {
    system('killall sp-sc');
}