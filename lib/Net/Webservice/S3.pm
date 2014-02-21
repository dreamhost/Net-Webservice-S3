use 5.010;
use strict;

package Net::Webservice::S3;

=head1 NAME

Net::Webservice::S3 - a simple but powerful interface to S3-compatible object stores

=head1 FUNCTIONS

=over

=cut

our $VERSION = "0.010";

use Carp ();
use POSIX ();

use LWP::UserAgent ();
use HTTP::Request ();

use URI ();
use URI::Escape ();

use Digest::HMAC ();
use Digest::SHA1 ();

use XML::Simple ();

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

=item *

s3.amazonaws.com (Amazon S3)

=item *

objects.dreamhost.com (DreamObjects)

=item *

storage.googleapis.com (Google Cloud Storage)

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

=item debug

Causes S3 to spew out a bunch of debugging messages to standard error.

=item retry

The number of additional attempts that will be made to perform requests
following a HTTP 5xx error. Default is 3; use 0 to disable retries entirely.

=item retry_delay

The (integer) number of seconds to wait between retries. Default is 1.

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

	$self->{debug} = delete $args{debug};

	$self->{retry} = delete $args{retry} // 3;
	$self->{retry_delay} = delete $args{retry_delay} // 1;

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


=item $S3->buckets()

Returns an array of Net::Webservice::S3::Bucket instances for each bucket
owned by the current user.

=cut

sub buckets {
	my ($self) = @_;
	my $res = $self->xml_request(
		HTTP::Request->new(GET => $self->uri())
	);
	return map {
		$self->bucket($_->{Name}->[0])
	} @{ $res->{ListAllMyBucketsResult}->[0]->{Buckets}->[0]->{Bucket} };
}

=back

=head2 PLUMBING

The following functions are intended primarily for internal use by
Net::Webservice::S3. They may be useful if you need to access some
functionality that isn't currently exposed by the module, but they should be
considered a last resort.

=over

=cut


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
	if ($ReqURI->query) {
		for my $part (split /&/, $ReqURI->query) {
			if (my ($k, $v) = $part =~ m{
				^ (
					acl | lifecycle | location | logging | notification |
					partNumber | policy | requestPayment | torrent | uploadId |
					uploads | versionId | versioning | versions | website |
					delete |
					response- (?:
						content-type | content-language | expires |
						cache-control | content-disposition | content-encoding
					)
				)
				( = .* )? $
			}x){
				# Q: What happens if a subresource is duplicated?
				# Documentation doesn't say.
				$subres{$k} = URI::Escape::uri_unescape($v // "");
			}
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

If the request does not already have a Date header, one is added as part of the
signing process. (It will not be used if an Expires or X-AMZ-Date header is
present, but is added regardless.)

=cut

sub sign_request {
	my ($self, $req) = @_;

	my $access_key = $self->access_key;
	return if !defined $access_key;

	if (!$req->header("Date")) {
		$req->header("Date" => POSIX::strftime("%a, %d %b %Y %T GMT", gmtime));
	}

	my $sig = Digest::HMAC->new(
		$self->secret_key, "Digest::SHA1"
	)->add(
		$self->_sign_request_string($req)
	)->b64digest() . "="; # Digest::HMAC leaves out padding

	$req->header(Authorization => "AWS $access_key:$sig");

	return $sig;
}


=item $S3->run_request($Request, %options)

Given an HTTP::Request instance representing a request to be made to the S3
endpoint, the request is signed and executed, and the results are returned
as an HTTP::Response instance.

If the request fails with a 5xx error, it is automatically retried unless the
C<error_ok> option is set.

Options may be drawn from the set:

=over

=item error_ok

Returns HTTP 5xx errors, rather than retrying them or throwing an exception.

=back

=cut

sub run_request {
	my ($self, $Req, %opts) = @_;

	$self->sign_request($Req);
	print STDERR "--- SEND ---\n" . $Req->as_string if $self->{debug};

	my $Res;
	my $retry_state = {};
	do {
		$Res = $self->agent->request($Req);
		print STDERR "--- RECV ---\n" . $Res->as_string . "\n" if $self->{debug};
		return $Res if $self->_should_accept_response($Res, \%opts);
	} while ($self->_should_retry_request($Req, \%opts, $retry_state));

	my $code = $Res->code;
	Carp::croak("Request failed (HTTP $code)");
}


# $S3->_should_accept_response($Response, \%options)
#
# Should this response be "accepted" and returned to the caller?

sub _should_accept_response {
	my ($self, $Response, $opts) = @_;
	return $Response->code < 500 || $opts->{error_ok};
}


# $S3->_should_retry_request($Request, $Response, \%options, \%state)
#
# Given that this request has failed, should we try it again?

sub _should_retry_request {
	my ($self, $Req, $opts, $state) = @_;
	return 0 if $state->{try}++ >= $self->{retry};
	sleep $self->{retry_delay};
	return 1;
}


=item $S3->xml_request($request, %options)

Runs the specified request with XML input and output: if C<data> is set in the
options, it is serialized as XML data and passed in the body of the request,
and if the request returns XML data, it is deserialized and returned.

If the XML-layer response contains an C<< <Error /> >> as its root element, an
exception is thrown unless the C<error_ok> option is set.

If the HTTP-layer response is not a 2xx success, an exception is thrown unless
the C<error_ok> option is set. Additionally, if that option is set to 500, HTTP
5xx errors are passed through as well, and do not trigger automatic request
retries.

When called in array context, this function returns an array consisting of the
decoded response and the raw L<HTTP::Response>. In scalar context, only the
decoded response is returned.

L<XML::Simple> semantics (with ForceArray and KeepRoot both set) are used for
parsing and generating XML.

Options may be drawn from the set:

=over

=item data

A Perl data structure to be serialized and sent in the body of the request.

=item error_ok

Causes non-200 HTTP responses and XML errors (including parsing errors) to not
be thrown as exceptions.

If the option is set to 500, the C<error_ok> option is also passed through to
C<< $S3->run_request() >>, causing server errors to be passed on and not cause
retries.

Note that some error messages may only be apparent in the response data, and
the response data may not be parsed if it was invalid. Do not set C<error_ok>
unless you intend to handle all such errors yourself!

=back

=cut

sub xml_request {
	my ($self, $req, %opts) = @_;

	my $XML = XML::Simple->new(
		ForceArray => 1,
		KeepRoot => 1,
	);

	my $data = delete $opts{data};
	my $error_ok = delete $opts{error_ok};

	if (my (@args) = keys %opts) {
		Carp::croak("Unexpected arguments to Net::Webservice::S3->xml_request: @args");
	}

	my %reqopts;
	$reqopts{error_ok} = 1 if $error_ok == 500;

	$req->content($XML->XMLout($data)) if defined $data;
	my $res = $self->run_request($req, %reqopts);
	my $rdata = $res->decoded_content;
	if ($res->content_type =~ m{^(text|application)/xml}) {
		# Catch errors in XML parsing
		my $decode = eval { $XML->parse_string($rdata); };
		if (defined $decode) {
			$rdata = $decode;
		} else {
			Carp::croak("Invalid XML in response") if !$error_ok;
		}
	}

	if (!$error_ok) {
		if (ref $rdata && $rdata->{Error}) {
			my $err = $rdata->{Error}->[0];
			my $code = $err->{Code}->[0];
			my $message = $err->{Message}->[0];
			Carp::croak("$code: $message");
		}

		# Check for HTTP error *after* XML error, as many HTTP errors will
		# contain a more useful explanation of what went wrong in the response
		# body.
		if ($res->code >= 300) {
			Carp::croak("HTTP " . $res->code);
		}
	}

	if (wantarray) {
		return ($rdata, $res);
	} else {
		return $rdata;
	}
}


=back

=head1 SEE ALSO

Other distributions of possible interest:

=over

=item *

L<Net::Amazon::S3>

=item *

L<Net::Async::Webservice::S3>

=back


=head1 AUTHOR

Andrew Farmer <andrew.farmer@dreamhost.com>


=head1 LICENSE

Copyright (c) 2013 - 2014, DreamHost (LLC)

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

=over

=item *

Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

=item *

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
