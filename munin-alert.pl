#!/usr/bin/perl

use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use Sys::Syslog;
use threads;
use YAML qw(LoadFile);
use strict;
use warnings;

openlog('munin-alert', 'cons,pid', 'user');

my $msgid = -1;
my @threads;
my @data = ();

# Parsing config
my $config = LoadFile('/etc/munin-alert.yml');

my $hipchat_url = $config->{'hipchat'}->{'api_url'};
my $hipchat_key = $config->{'hipchat'}->{'api_key'};
my $hipchat_room = $config->{'hipchat'}->{'room_id'};

my $pagerduty_url = $config->{'pagerduty'}->{'api_url'};
my $pagerduty_key = $config->{'pagerduty'}->{'api_key'};

my %actions = ( 'pagerduty' => \&sendToPagerDuty,
		'hipchat' => \&sendToHipChat
		);

sub sendToPagerDuty {
	my $msg = shift;

	syslog('info', 'MSG: [%s] Sending alert (%s) to pagerduty', $msg->{'id'}, $msg->{'host'}.':'.$msg->{'graph'}.'; '.$msg->{'text'});

	my $ua = LWP::UserAgent->new;

	my $event_type;
	$event_type = 'trigger' if (($msg->{'status'} eq 'critical') || ($msg->{'status'} eq 'warning') || ($msg->{'status'} eq 'unknown')) ;
        $event_type = 'resolve' if ($msg->{'status'} eq 'ok');

	my $hash = $msg->{'host'}.$msg->{'graph'};
	my $incident_key = md5_hex($hash);

	my $req = HTTP::Request->new(POST => $pagerduty_url);
	$req->header('Content-type' => 'application/json');

	my $post_data = '{ "service_key": "'.$pagerduty_key.'", "event_type": "'.$event_type.'", "incident_key": "'.$incident_key.'", "description": "'.$msg->{'host'}.':'.$msg->{'graph'}.'; '.$msg->{'text'}.'" }';
	$req->content($post_data);

	my $resp = $ua->request($req);
	if ($resp->is_success) {
		syslog('info', 'MSG: [%s] Successfully sent alert to pagerduty', $msg->{'id'});
	}
	else {
		my $message = $resp->decoded_content;

		syslog('warning', 'MSG: [%s] HTTP code: %s, message: %s', $msg->{'id'}, $resp->code, $message);
	}
}

sub sendToHipChat {
        my $msg = shift;

        syslog('info', 'MSG: [%s] Sending alert (%s) to hipchat', $msg->{'id'}, $msg->{'host'}.':'.$msg->{'graph'}.'; '.$msg->{'text'});

        my $ua = LWP::UserAgent->new;
        my $server_endpoint = "https://api.hipchat.com/v1/rooms/message?format=json&auth_token=6cc3b70459ea70a12dfc01fd190d7d";

        my $req = HTTP::Request->new(POST => $hipchat_url.'?format=json&auth_token='.$hipchat_key);
        $req->header('Content-type' => 'application/x-www-form-urlencoded');

        my $post_data = 'room_id='.$hipchat_room.'&from=MuninAlerts&message='.$msg->{'host'}.':'.$msg->{'graph'}.'; '.$msg->{'text'};
	$req->content($post_data);

        my $resp = $ua->request($req);
        if ($resp->is_success) {
                syslog('info', 'MSG: [%s] Successfully sent alert to hipchat', $msg->{'id'});
        }
        else {
                my $message = $resp->decoded_content;

                syslog('warning', 'MSG: [%s] HTTP code: %s, message: %s', $msg->{'id'}, $resp->code, $message);
        }
}

foreach my $line ( <STDIN> ) {
	chomp $line;

	if ($line =~ m/\:\:/g) {
		$msgid++;
		my @values = split(' :: ', $line);

		# Setting message data
		$data[$msgid]{'id'} = $msgid;
		$data[$msgid]{'host'} = $values[-2];
		$data[$msgid]{'graph'} = $values[-1];
	} else {
		# Removing spaces from start and end of line
		$line =~ s/^\s+|\s+$//;

		# Setting message text
		$data[$msgid]{'text'} .= $line."; " if (length($line) > 0);

		# Setting message status
		$data[$msgid]{'status'} = 'ok' if ($line =~ m/OKs\:/g);
		$data[$msgid]{'status'} = 'warning' if ($line =~ m/WARNINGs\:/g);
		$data[$msgid]{'status'} = 'critical' if ($line =~ m/CRITICALs\:/g);
		$data[$msgid]{'status'} = 'unknown' if ($line =~ m/UNKNOWNs\:/g);
	}
}

foreach my $alert (@data) {
	if (exists $config->{'munin'}->{$alert->{'status'}}) {
		foreach my $action (@{$config->{'munin'}->{$alert->{'status'}}}) {
			push @threads, threads->create($actions{$action}, $alert);
		}
	} else {
		syslog('info', 'Nothing action is defined for status %s, skipping', $alert->{'status'});
	}
}

foreach my $thread (@threads) {
    $thread->join();
}

closelog();
