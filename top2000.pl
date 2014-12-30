#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use DaZeus;
use Try::Tiny;

my ($sock, $network, $channel) = @ARGV;
if(!$channel) {
	die "Usage: $0 socket network channel";
}

my $json_url = "http://top2012.radio2.nl/data/cache/json/nowplaying.json";
my $last_song_id;

while(1) {
	my $song = get_new_song();
	if(!$song) {
		sleep 5;
		next;
	}

	my $message = "TOP 2000 - Just started: " . $song->{'artist'} . " - " . $song->{'title'} . " - Listen in: http://radioplayer.npo.nl/radio2/";
	print $message . "\n";
	try {
		my $dazeus = DaZeus->connect($sock);
		$dazeus->message($network, $channel, $message);
	} catch {
		print "Failed to deliver message: $_\n";
	};

	my $time_left = $song->{'expires'} - time;
	if($time_left > 6) {
		print "Sleeping $time_left - 6\n";
		sleep $time_left - 6;
	}
}

sub get_new_song {
	my $body = `wget -qO- "$json_url"`;
	my $obj = decode_json($body);
	my $id = $obj->{'id'};
	if($last_song_id && $last_song_id == $id) {
		return undef;
	} else {
		$last_song_id = $id;
		return $obj;
	}
}

