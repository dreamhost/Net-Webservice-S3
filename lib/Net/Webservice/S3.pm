use 5.010;
use strict;

package Net::Webservice::S3;

our $VERSION = "0.01";

use Carp;
use POSIX;

use LWP::UserAgent;
use HTTP::Request;

use Digest::HMAC;
use Digest::SHA1;


sub new {
	my ($cls, %args) = @_;

	my $self = bless {}, $cls;

	$self->{access_key} = delete $args{access_key};
	$self->{secret_key} = delete $args{secret_key};
	if (length $self->{secret_key} and !length $self->{access_key}) {
		Carp::croak("secret_key is meaningless without an access_key");
	}

	$self->{host} = delete $args{host} // "s3.amazonaws.com";
	$self->{ssl} = delete $args{ssl} // 1;

	my $ua = delete $args{ua} // "Net::Webservice::S3 $VERSION";
	$self->{agent} = delete $args{agent} // LWP::UserAgent->new(agent => $ua);

	if (my (@args) = keys %args) {
		Carp::croak("Unexpected arguments to Net::Webservice::S3->new: @args");
	}

	return $self;
}


sub _sign_request_string {
	my ($self, $req, $expires) = @_;

	my %amz_headers;
	$req->headers->scan(sub {
		my ($field, $val) = @_;
		return if lc $field eq "x-amz-date";
		push @{$amz_headers{lc $field}}, $val if $field =~ m{^x-amz-}i;
	});
	my @canon_headers = map {
		$_ . ":" . join ",", @{$amz_headers{$_}}
	} sort keys %amz_headers;

	my $URI = URI->new($req->uri);
	my $host = lc ($req->header("Host") // $URI->host);
	my $suffixlen = 1 + length $self->{host};

	my $canon_resource = "";

	if ($host eq $self->{host}) {
		# Do nothing
	} elsif (substr($host, -$suffixlen) eq "." . $self->{host}) {
		$canon_resource .= "/" . substr($host, 0, -$suffixlen);
	} else {
		$canon_resource .= "/" . $host;
	}

	$canon_resource .= $URI->path || "/";

	my %subres;
	for my $part (split /&/, $URI->query) {
		if (my ($k, $v) = $part =~ m{
			^ (
				acl | lifecycle | location | logging | notification |
				partNumber | policy | requestPayment | torrent | uploadId |
				uploads | versionId | versioning | versions | website
			)
			( = .* )? $
		}x){
			# Q: What happens if a subresource is duplicated?
			# Documentation doesn't say.
			$subres{$k} = $v;
		}
	}

	$canon_resource .= "?" . join "&" => map {
		$_ . $subres{$_}
	} sort keys %subres if keys %subres;

	return join "\n", (
		$req->method,
		$req->header("Content-MD5") // "",
		$req->header("Content-Type") // "",
		$req->header("Expires") // $req->header("X-AMZ-Date") // $req->header("Date"),
		@canon_headers,
		$canon_resource
	);
}


sub sign_request {
	my ($self, $req) = @_;
	return if !defined $self->{access_key};
	my $sig = Digest::HMAC->new(
		$self->{secret_key}, "Digest::SHA1"
	)->add(
		$self->_sign_request_string($req)
	)->b64digest() . "="; # Digest::HMAC leaves out padding
	$req->header(Authorization => "AWS $self->{access_key}:$sig");
	return $sig;
}


sub run_request {
	my ($self, $req) = @_;
	$req->header("Date" => POSIX::strftime("%a, %d %b %Y %T %z", gmtime));
	$self->sign_request($req);
	return $self->{agent}->request($req);
}


1;
