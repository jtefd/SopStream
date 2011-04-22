#!/usr/bin/env perl

=pod

=head1 NAME

sopstream

=head1 SYNOPSIS

sopstream --start CHANNEL_NAME | --list-channels

=head1 OPTIONS

=over 8

=item B<--start CHANNEL_NAME | -s CHANNEL_NAME>

Starts streaming the given named channel.

=item B<--list-channels | -l>

Lists all known channels.

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

sub getChannels(;$) {
	my ($search) = @_;
	
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

sub checkPort($) {
	my ($port) = @_;
	
	my $sock = IO::Socket::INET->new(
		PeerAddr => 'localhost',
		PeerPort => $port, 
		Proto => 'tcp'
	) or return 1;
	
	return undef;
}

sub getPorts() {
	my $start = 1;
	
	while($start <= 9) {
		my ($local, $player) = ("890$start", "891$start");
		
		if (checkPort($local) && checkPort($player)) {
			return ($local, $player);
		}
		else {
			$start++;
		}
	}
	
	return undef;
}

my %opts;

GetOptions(
	\%opts,
	'list-channels|l',
	'start|s=s',
	'background|b',
	'kill|k',
	'help'
);

if ($opts{'help'} || scalar(keys %opts) == 0) {
	pod2usage( -verbose => 1, -exitval => 0 )
}

my %channels = getChannels();

if ($opts{'list-channels'}) {
	print $_, "\n" foreach sort keys %channels;
}
elsif ($opts{'start'}) {
	if (defined(my $link = $channels{$opts{'start'}})) {
		if (my ($local, $player) = getPorts()) {
			my $cmd = sprintf('sp-sc %s %s %s', $link, $local, $player);
		
			if ($opts{'background'}) {
				$cmd = sprintf('nohup %s > /dev/null 2> /dev/null &', $cmd);
			}
		
			system($cmd);	
		}
	}
}
elsif ($opts{'kill'}) {
	system('killall sp-sc');
}