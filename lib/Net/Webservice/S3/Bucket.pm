use 5.010;
use strict;

package Net::Webservice::S3::Bucket;

use Carp ();
use HTTP::Request ();

=head1 NAME

Net::Webservice::S3::Bucket - a S3 bucket

=head1 FUNCTIONS

=over

=item Net::Webservice::S3::Bucket->new($Connection, $name)

Creates an object representing an S3 bucket with the given name, accessed
through the specified Net::Webservice::S3 connection.

The bucket is not created, or even checked for existence, as part of this
operation.

=cut

sub new {
	my ($cls, $Connection, $name) = @_;
	if (!$Connection->isa("Net::Webservice::S3")) {
		Carp::croak("Invalid connection");
	}
	return bless {
		name => $name,
		conn => $Connection,
	}, $cls;
}


=item $Bucket->name

Returns the name of this bucket.

=cut

sub name {
	my ($self) = @_;
	return $self->{name};
}


=item $Bucket->connection

Returns the S3 connection used by this bucket.

=cut

sub connection {
	my ($self) = @_;
	return $self->{conn};
}


=item $Bucket->uri($path, [$query])

Returns a fully qualified URI for the specified path under this bucket,
optionally with the specified query.

The path is always treated as an object name (i.e, a relative path), even if it
begins with a slash. To refer to the root of the bucket, use a path of C<"">,
not C<"/">.

The query is used as-is if it is a scalar, or as a set of URL-encoded query
parameters (as key-value pairs) if it is an array reference.

=cut

sub uri {
	my ($self, $path, $query) = @_;
	$path //= "";
	return $self->connection->uri($self->name . "/" . $path, $query);
}


=item $Bucket->key($key)

Creates a Net::Webservice::S3::Key instance representing the key with the
specified name in this bucket.

As with the analogous method S3->bucket(), the key is not created or checked
for existence.

=cut

sub key {
	my ($self, $name) = @_;
	require Net::Webservice::S3::Key;
	return Net::Webservice::S3::Key->new($self, $name);
}


=item $Bucket->exists()

Returns a true value if the bucket exists. (Including if it exists but is owned
by someone else.)

=cut

sub exists {
	my ($self) = @_;
	my ($code) = $self->connection->xml_request(
		HTTP::Request->new(HEAD => $self->uri(""))
	);

	return 0 if $code == 404;
	return 1 if $code == 200 or $code == 403;

	# We're not sure if this exists. Let's pretend it does exist, because
	# that does mean it can't be created (which is what probably matters).
	Carp::carp("Got HTTP $code on bucket HEAD");
	return 1;
}


=item $Bucket->create(%opts)

Creates this bucket, and returns a true value when the bucket is created
(or if it has previously been created by this user).

Options must be drawn from the set:

=over

=item acl

Not yet supported. Watch this space.

=item location

The internal name of a region for the bucket to be created in.

Valid values will vary based on the provider being used.

=back

=cut

sub create {
	my ($self, %args) = @_;
	my $req = {};

	if (my $loc = delete $args{location}) {
		$req->{LocationConstraint} = [$loc];
	}

	if (my (@args) = keys %args) {
		Carp::croak("Unexpected arguments to Net::Webservice::S3::Bucket->create @args");
	}

	my ($code, $ign, $res) = $self->connection->xml_request(
		HTTP::Request->new(PUT => $self->uri()),
		{ "CreateBucketConfiguration" => [{}] }
	);
	if ($code == 200) {
		return 1;
	} else {
		die "HTTP $code while creating bucket";
	}
}


=item $Bucket->destroy()

Deletes the bucket, and returns a true value on success.

The bucket must be empty before it can be deleted.

=cut

sub destroy {
	my ($self) = @_;

	my ($code) = $self->connection->xml_request(
		HTTP::Request->new(DELETE => $self->uri())
	);
	if ($code == 204) { # No content (success)
		return 1;
	} else {
		die "HTTP $code while destroying bucket";
	}
}


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
