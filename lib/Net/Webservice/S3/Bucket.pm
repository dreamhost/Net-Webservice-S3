use 5.010;
use strict;

package Net::Webservice::S3::Bucket;

use Carp;

=head1 NAME

Net::Webservice::S3::Bucket - a S3 bucket

=head1 FUNCTIONS

=over

=item Net::Webservice::S3::Bucket->new($name, $Connection)

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
	return $self->connection->uri($self->name . "/" . $path, $query);
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
