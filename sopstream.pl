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
use Sys::Hostname;

use vars qw/$VERSION $VERBOSE/;

$VERSION = '0.0.1';

sub Log($) {
	my ($msg) = @_;
	
	print STDERR $msg, "\n" if $VERBOSE;
}

sub GetChannels() {
    my $channels = {};
    
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
            
            my $key = uc($channel_name);
            
            if ($channel_name =~ /\w$/) {
                $channels->{$key}->{_NAME} = $channel_name;
                $channels->{$key}->{_URL} = $channel_link;	
            }
        }
    }
    
    return $channels;
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
	my ($broker_url, $background) = @_;
	
	if (my ($local_port, $player_port) = GetPorts()) {
    	my $cmd = sprintf('sp-sc %s %s %s', $broker_url, $local_port, $player_port);
    	
    	Log(sprintf('Streaming %s to http://%s:%s', $broker_url, hostname, $player_port));
    	
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
    'verbose|v',
    'help'
);

if ($opts{'verbose'}) {
	$VERBOSE = 1;
}

if ($opts{'help'} || scalar(keys %opts) == 0) {
    pod2usage( -verbose => 1, -exitval => 0 )
}

if ($opts{'list-channels'}) {
	my $channels = GetChannels();
	
	foreach (sort keys %{$channels}) {
		print $channels->{$_}->{_NAME}, "\n";
	}
}
elsif ($opts{'find-channel'}) {
	my $channels = GetChannels();
	
    my $find_str = quotemeta($opts{'find-channel'});
	
	foreach (sort keys %{$channels}) {
		my $name = $channels->{$_}->{_NAME};
			
		if ($name =~ /$find_str/i) {
			print $name, "\n";
		}
	}
}
elsif ($opts{'start'}) {	
	if ($opts{'start'} =~ /^sop:\/\//) { # By URL
		StartSopCast($opts{'start'}, $opts{'background'});
	}
	elsif ($opts{'start'} =~ /^\d+$/) { # By channel number
		StartSopCast(sprintf('sop://broker.sopcast.com:3912/%s', $opts{'start'}), $opts{'background'});
	}
	else {
		my $channels = GetChannels();
		
		my $link = $channels->{uc($opts{'start'})};
		
		unless ($link) {
			my $find_str = quotemeta($opts{'start'});
			
			foreach (sort keys %{$channels}) {
                my $name = $channels->{$_}->{_NAME};
            
                if ($name =~ /$find_str/i) {
                	Log(sprintf('Selecting channel: %s', $name));
                    $link = $channels->{$_}->{_URL};
                    last;
                }
			}
		}
		
		if ($link) {
            StartSopCast($link, $opts{'background'});	
		}
	}
}
elsif ($opts{'kill'}) {
    system('killall sp-sc');
}