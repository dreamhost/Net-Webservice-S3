use 5.010;
use strict;

package Net::Webservice::S3::Key;

use Carp ();

=head1 NAME

Net::Webservice::S3::Key - an object in an S3 bucket

=head1 FUNCTIONS

=over

=item Net::Webservice::S3::Key->new($Bucket, $name)

Creates an object representing an S3 key with the given name in the specified
bucket.

The S3 object is not created, or even checked for existence, as part of this
operation.

=cut

sub new {
	my ($cls, $Bucket, $name) = @_;
	if (!$Bucket->isa("Net::Webservice::S3::Bucket")) {
		Carp::croak("Invalid bucket");
	}
	return bless {
		name => $name,
		bucket => $Bucket,
	}, $cls;
}


=item $Key->name

Returns the name of this key.

=cut

sub name {
	my ($self) = @_;
	return $self->{name};
}


=item $Key->bucket

Returns the bucket this key exists in.

=cut

sub bucket {
	my ($self) = @_;
	return $self->{bucket};
}


=item $Key->connection

Return the S3 connection used by this key (through the bucket).

=cut

sub connection {
	my ($self) = @_;
	return $self->bucket->connection;
}


=item $Key->uri([$query])

Returns a fully qualified URI for this key, optionally with the specified
query.

The query is used as-is if it is a scalar, or as a set of URL-encoded query
parameters (as key-value pairs) if it is an array reference.

=cut

sub uri {
	my ($self, $query) = @_;
	return $self->bucket->uri($self->name, $query);
}


=item $Key->signed_uri(%opts)

Returns a fully qualified pre-signed URI for this key.

Options must be drawn from the set:

=over

=item expire

An absolute time for the signature to expire, represented as an integer time_t.

=item lifetime

The amount of time the signature should be valid for, represented as a number
of seconds.

=item method

The method of request to sign. Defaults to C<GET>.

=item query

Query string options to be used on the URI, in either of the forms accepted by
Key->uri. This can be used for signing a URL to access special subresources
such as C<acl>.

=item content_type

=item content_md5

Special headers to incorporate into the signature. These are usually used when
signing URLs for PUT.

=back

Exactly one of C<expire> and C<lifetime> must be specified. The rest of the
options are optional.

=cut

sub signed_uri {
	my ($self, %opts) = @_;
	my $expires;

	if ($expires = delete $opts{expire}) {
		# OK
	} elsif (my $lifetime = delete $opts{lifetime}) {
		$expires = time + $lifetime;
	} else {
		Carp::croak("Either expire or lifetime must be specified");
	}

	my $method = delete $opts{method} // "GET";
	my $query  = delete $opts{query};
	my $content_md5 = delete $opts{content_md5};
	my $content_type = delete $opts{content_type};

	my @query;
	if (ref $query) {
		@query = @$query;
	} elsif (defined $query) {
		# This ends up generating a query like:
		#     ?AWSAccessKeyID=...&Signature=...&Expires=...&acl=
		# which both AWS and DHO will accept and interpret as intended.
		# (I haven't tested GCS; someone else should!)
		@query = ($query => "");
	}

	if (my (@args) = keys %opts) {
		Carp::croak("Unexpected arguments to Net::Webservice::S3::Key->signed_uri: @args");
	}

	$expires = int $expires;
	Carp::croak("Invalid expiration time") if $expires <= 0;

	my $req = HTTP::Request->new($method => $self->uri($query));
	$req->header(Expires => $expires);
	$req->header("Content-Type" => $content_type) if defined $content_type;
	$req->header("Content-MD5" => $content_md5) if defined $content_md5;
	my $sig = $self->connection->sign_request($req);

	return $self->uri([
		AWSAccessKeyId => $self->connection->access_key,
		Signature => $sig,
		Expires => $expires,
		@query,
	]);
}


=back

=head1 AUTHOR

Andrew Farmer <andrew.farmer@dreamhost.com>


=head1 LICENSE

Copyright (c) 2013, New Dream Network LLC (dba DreamHost)

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
