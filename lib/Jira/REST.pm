package Jira::REST;

use strict;
use warnings;

use LWP;
use HTTP::Request;
use JSON;

use deploy::Config;
use Google::Chrome::CookieJar;

sub new {
	my ($class) = @_;

	my $ua = new LWP::UserAgent;
	$ua->timeout(25);

	my $self = {
		cookie => Google::Chrome::CookieJar->new()->get_cookie_string(deploy::Config->jira_domain),
		ua     => $ua
	};

	return bless $self, $class;
}

sub _request {
	my ($self, $method, $request_params, $data) = @_;

	my $jira_url = deploy::Config->jira_url;

	if ($request_params =~ /latest\/issue/ ) {
		$jira_url = deploy::Config->jira_url_v1;
	}

	my $request = HTTP::Request->new( $method => "$jira_url/$request_params" );
	$request->content_type('application/json');
	$request->header( 'Cookie' => $self->{cookie} );
	$request->content($data) if $data;

	my $resp = $self->{ua}->request($request);

	if ( $resp && $resp->is_success ) {
		my $content = $resp->content();
		return JSON::decode_json( $content ) if $content;
	} else {
		return undef;
	}	
}

sub get_request {
	my ($self, $request_params) = @_;
	return $self->_request('GET', $request_params, undef);
}

sub put_request {
	my ($self, $request_params, $data) = @_;
	return $self->_request('PUT', $request_params, $data);
}

sub post_request {
	my ($self, $request_params, $data) = @_;
	return $self->_request('POST', $request_params, $data);
}

sub get_project {
	my ($self, $project_id) = @_;

	return $self->get_request("project/$project_id");
}

sub get_version_issues {
	my ($self, $version) = @_;

	return $self->get_request("search?jql=fixVersion=$version");
}

sub update_issue_status {
	my ($self, $issue) = @_;

	my $data = '{"transition":{"id": "501"}}';

	return $self->post_request("latest/issue/$issue/transitions", $data);
}

1;
