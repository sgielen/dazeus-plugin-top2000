#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use DaZeus;
use Try::Tiny;
use Text::Fuzzy;

my ($sock, $network, $channel) = @ARGV;
if(!$channel) {
	die "Usage: $0 socket network channel";
}

my $json_url = "http://top2012.radio2.nl/data/cache/json/nowplaying.json";
my $last_song_id;

my @songs = top2000_songs();

while(1) {
	my $song = get_new_song();
	if(!$song) {
		sleep 5;
		next;
	}

	my $score = find_score($song->{'artist'}, $song->{'title'}, \@songs) || "(unknown)";
	my $next_song = $songs[$score - 2];

	my $message = "TOP 2000 - #$score " . $song->{'artist'} . " - " . $song->{'title'};
	if($next_song) {
		$message .= "\nNext up: " . $next_song->[1] . " - " . $next_song->[2];
	}
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

sub find_score {
	my ($artist, $title, $songs) = @_;
	$artist = Text::Fuzzy->new($artist);
	$title = Text::Fuzzy->new($title);
	# This is awkwardly inefficient but I'm in a hurry
	my $lowest_distance;
	my $id;
	for my $song (@$songs) {
		# [id, artist, title, datetime]
		my $distance = $artist->distance($song->[1]);
		$distance += $title->distance($song->[2]);
		if(!defined($lowest_distance) || $lowest_distance > $distance) {
			$lowest_distance = $distance;
			$id = $song->[0];
		}
		if($distance == 0) {
			# perfect match found
			last;
		}
	}
	return $id;
}

sub top2000_songs {
	open my $fh, "top2000.txt" or die $!;
	my @songs;
	while(<$fh>) {
		1 while chomp;
		push @songs, [split /\t/, $_];
	}
	close $fh;
	return @songs;
}
