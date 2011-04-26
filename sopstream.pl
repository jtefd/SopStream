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

package SopStream::Util;

use strict;
use warnings;

use File::Basename qw/dirname/;
use File::Path qw/mkpath/;
use File::Spec::Functions qw/catfile/;
use File::stat;
use HTML::TreeBuilder;
use IO::Socket;
use LWP::UserAgent;
use Sys::Hostname;
use XML::Simple;

use vars qw/$VERSION $VERBOSE $CHANNEL_LIST_CACHE_FILE $CHANNEL_LIST_CACHE/;

$VERSION = '0.1.0';
$CHANNEL_LIST_CACHE_FILE = catfile($ENV{HOME}, '.sopstream', 'channel_list.xml');

sub Log($) {
	my ($msg) = @_;
	
	print STDERR $msg, "\n" if $VERBOSE;
}

sub StashChannelList() {
	unless (-d dirname($CHANNEL_LIST_CACHE_FILE)) {
	   mkpath(dirname($CHANNEL_LIST_CACHE_FILE));	
	}
	
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
            	push @{$channels->{channel}}, {
            		id => $key,
            		name => $channel_name,
            		url => $channel_link
            	};
            }
        }
    }
	
	open CACHE_FILE, ">$CHANNEL_LIST_CACHE_FILE";
	
	print CACHE_FILE XMLout($channels, RootName => 'channel_list', XMLDecl => '<?xml version="1.0" encoding="UTF-8"?>');
	
	close CACHE_FILE;
}

sub GetChannels() {
	unless ($CHANNEL_LIST_CACHE) {
	    if (-f $CHANNEL_LIST_CACHE_FILE) {
            my $diff = time - stat($CHANNEL_LIST_CACHE_FILE)->mtime;
        
	        if ($diff > (60*60*24*7)) {
	            StashChannelList();
	        }
        }
        else {
            StashChannelList(); 
        }
	    
	    my $xml_data = XMLin($CHANNEL_LIST_CACHE_FILE, ForceArray => 1, KeepRoot => 1);
	    
	    my $channel_list = $xml_data->{channel_list}[0]->{channel};
	    
	    my $channels = {};
	    
	    foreach my $name (sort keys %{$channel_list}) {
	        my $id = $channel_list->{$name}->{id};
	        my $url = $channel_list->{$name}->{url};
	        
	        $channels->{$id}->{_NAME} = $name;
	        $channels->{$id}->{_URL} = $url;
	    }
	    
	    $CHANNEL_LIST_CACHE = $channels;	
	}
    
    return $CHANNEL_LIST_CACHE;
}

sub FindChannels($) {
	my ($query) = @_;
	
	my $channels = GetChannels();
	my $results = $channels;
    
    my $find_str = quotemeta($query);
    
    foreach (sort keys %{$channels}) {
        my $name = $channels->{$_}->{_NAME};
            
        unless ($name =~ /$find_str/i) {
            delete $results->{$_};
        }
    }
    
    return $results;
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

sub KillSopCast() {
	system('killall sp-sc');
}

1;

package SopStream::Main;

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

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
	$SopStream::Util::VERBOSE = 1;
}

if ($opts{'help'} || scalar(keys %opts) == 0) {
    pod2usage( -verbose => 1, -exitval => 0 )
}

if ($opts{'list-channels'}) {
	my $channels = SopStream::Util::GetChannels();
	
	foreach (sort keys %{$channels}) {
		print $channels->{$_}->{_NAME}, "\n";
	}
}
elsif ($opts{'find-channel'}) {
	my $channels = SopStream::Util::FindChannels($opts{'find-channel'});
	
	foreach (sort keys %{$channels}) {
		my $name = $channels->{$_}->{_NAME};
			
		print $name, "\n";
	}
}
elsif ($opts{'start'}) {	
	if ($opts{'start'} =~ /^sop:\/\//) { # By URL
		SopStream::Util::StartSopCast($opts{'start'}, $opts{'background'});
	}
	elsif ($opts{'start'} =~ /^\d+$/) { # By channel number
		SopStream::Util::StartSopCast(sprintf('sop://broker.sopcast.com:3912/%s', $opts{'start'}), $opts{'background'});
	}
	else { # By name / search
		my $channels = SopStream::Util::GetChannels();
		
		my $link = $channels->{uc($opts{'start'})};
		
		unless ($link) {
			$channels = SopStream::Util::FindChannels($opts{'start'});
    
            foreach (sort keys %{$channels}) {
                my $name = $channels->{$_}->{_NAME};
                $link = $channels->{$_}->{_URL};
                SopStream::Util::Log(sprintf('Selecting channel: %s', $name));
                last;
            }
		}
		
		if ($link) {
            SopStream::Util::StartSopCast($link, $opts{'background'});	
		}
	}
}
elsif ($opts{'kill'}) {
	SopStream::Util::KillSopCast();
}