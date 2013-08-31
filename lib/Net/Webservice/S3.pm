use 5.010;
use strict;

package Net::Webservice::S3;

=head1 NAME

Net::Webservice::S3 - a simple but powerful interface to S3-compatible object stores

=head1 FUNCTIONS

=over

=cut

our $VERSION = "0.01";

use Carp;
use POSIX;

use LWP::UserAgent;
use HTTP::Request;

use Digest::HMAC;
use Digest::SHA1;


=item Net::Webservice::S3->new(%opts)

Creates a new S3 instance, representing an interface with an S3 endpoint using
one specific (or no) access key.

Options must be drawn from the set:

=over

=item access_key

=item secret_key

The public and private components of the S3 key to be used. These options must
either both be present, or both be absent (implying anonymous access).

=item host

The hostname to be used to access S3. Required.

Recommended values include:

=over

=item

s3.amazonaws.com (Amazon S3)

=item

objects.dreamhost.com (DreamObjects)

=back

=item ssl

Set to 1 to use HTTPS to access the S3 endpoint. Enabled by default.

=item agent

A LWP::UserAgent instance (or compatible object) to be used to perform HTTP(S)
requests. If unset, an instance is created automatically.

=item ua

If C<agent> (above) is unset, the value of this option is used as the
User-Agent of the automatically created LWP::UserAgent. Defaults to a string
referring to this module.

=back

=cut

sub new {
	my ($cls, %args) = @_;

	my $self = bless {}, $cls;

	$self->{access_key} = delete $args{access_key};
	$self->{secret_key} = delete $args{secret_key};
	if (length $self->{secret_key} and !length $self->{access_key}) {
		Carp::croak("secret_key is meaningless without an access_key");
	}

	my $host = delete $args{host} or Carp::croak("host is required");
	my $ssl  = delete $args{ssl} // 1;

	my $uri = $self->{uri} = URI->new();
	$uri->scheme($ssl ? "https" : "http");
	$uri->host($host);

	my $ua = delete $args{ua} // "Net::Webservice::S3 $VERSION";
	$self->{agent} = delete $args{agent} // LWP::UserAgent->new(agent => $ua);

	if (my (@args) = keys %args) {
		Carp::croak("Unexpected arguments to Net::Webservice::S3->new: @args");
	}

	return $self;
}


=item $S3->access_key

Returns the access key used by this S3 connection.

=cut

sub access_key {
	my ($self) = @_;
	return $self->{access_key};
}


=item $S3->secret_key

Returns the secret key used by this S3 connection.

=cut

sub secret_key {
	my ($self) = @_;
	return $self->{secret_key};
}


=item $S3->agent

Returns the agent used by this S3 connection.

=cut

sub agent {
	my ($self) = @_;
	return $self->{agent};
}


=item $S3->uri([$path, [$query]])

Returns a fully qualified URI for the specified path relative to the S3
endpoint, or the URI of the endpoint if no path is specified.

If C<$query> is present as a scalar, it is appended as a query string.

If C<$query> is present as an arrayref, it is appended as a set of URL-encoded
query parameters (i.e, it is treated as a list of key/value pairs).

=cut

sub uri {
	my ($self, $path, $query) = @_;
	my $U = $self->{uri}->clone();
	# Leading slash is required here. URI adds one if none is present, but
	# this can make some paths with leading slashes not work.
	$U->path("/$path") if defined $path;
	if (ref $query eq "ARRAY") {
		$U->query_form($query);
	} elsif (ref $query) {
		Carp::croak("Invalid query");
	} elsif (defined $query) {
		$U->query($query);
	}
	return $U;
}


=item $S3->bucket($name)

Creates a Net::Webservice::S3::Bucket instance representing the bucket with the
specified name under this connection.

The bucket is not created or checked for existence as part of this operation.
Methods are provided on the bucket instance for both tasks.

=cut

sub bucket {
	my ($self, $name) = @_;
	require Net::Webservice::S3::Bucket;
	return Net::Webservice::S3::Bucket->new($self, $name);
}


# Given a request, generate the string to be used for HMAC1 signature.
# Split out to enable testing.

sub _sign_request_string {
	my ($self, $req) = @_;

	my %amz_headers;
	$req->headers->scan(sub {
		my ($field, $val) = @_;
		return if lc $field eq "x-amz-date";
		push @{$amz_headers{lc $field}}, $val if $field =~ m{^x-amz-}i;
	});
	my @canon_headers = map {
		$_ . ":" . join ",", @{$amz_headers{$_}}
	} sort keys %amz_headers;

	my $ReqURI = URI->new($req->uri);
	my $reqhost = lc ($req->header("Host") // $ReqURI->host);

	my $ephost = $self->uri->host;
	my $suffixlen = 1 + length $ephost;

	my $canon_resource = "";

	if ($reqhost eq $ephost) {
		# Do nothing
	} elsif (substr($reqhost, -$suffixlen) eq ".$ephost") {
		$canon_resource .= "/" . substr($reqhost, 0, -$suffixlen);
	} else {
		$canon_resource .= "/" . $reqhost;
	}

	$canon_resource .= $ReqURI->path || "/";

	my %subres;
	for my $part (split /&/, $ReqURI->query) {
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


=item $S3->sign_request($Request)

Given an HTTP::Request instance representing a request to be made to the S3
endpoint, the request is signed using the secret key present on the instance
(by applying an Authorization header), and the raw signature is returned.

=cut

sub sign_request {
	my ($self, $req) = @_;

	my $access_key = $self->access_key;
	return if !defined $access_key;

	my $sig = Digest::HMAC->new(
		$self->secret_key, "Digest::SHA1"
	)->add(
		$self->_sign_request_string($req)
	)->b64digest() . "="; # Digest::HMAC leaves out padding

	$req->header(Authorization => "AWS $access_key:$sig");

	return $sig;
}


=item $S3->sign_request($Request)

Given an HTTP::Request instance representing a request to be made to the S3
endpoint, the request is signed and executed, and the results are returned
as an HTTP::Response instance.

=cut

sub run_request {
	my ($self, $req) = @_;
	$req->header("Date" => POSIX::strftime("%a, %d %b %Y %T %z", gmtime));
	$self->sign_request($req);
	return $self->agent->request($req);
}


=back

=head1 SEE ALSO

Other distributions of possible interest:

=over

=item

L<Net::Amazon::S3>

=item

L<Net::Async::Webservice::S3>

=back


=head1 AUTHOR

Andrew Farmer <andrew.farmer@dreamhost.com>


=head1 LICENSE

Copyright (c) 2013, New Dream Network LLC (dba DreamHost)

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

=over

=item

Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

=item

Redistributions in binary form must reproduce the above copyright notice, this
list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1;
