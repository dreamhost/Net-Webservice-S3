use strict;
use Test::More tests => 4;
use Test::Exception;
use Test::Mock::LWP::Dispatch qw( $mock_ua );
use Net::Webservice::S3;

my $S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
	ua => $mock_ua,
);

my $B;

my $xml = <<EOF;
<CreateBucketConfiguration></CreateBucketConfiguration>
EOF

$mock_ua->map("https://s3.example.com/bucket/" => sub {
	my ($req) = @_;
	is($req->method, "PUT", "Request for bucket create is PUT");
	is($req->content, $xml, "Content for bucket create is correct");
	return HTTP::Response->new(200);
});

$B = $S3->bucket("bucket");
ok($B->create(), "Bucket created");

$mock_ua->map("https://s3.example.com/notyours/" => sub {
	return HTTP::Response->new(403);
});

$B = $S3->bucket("notyours");
dies_ok(sub { $B->create() }, "Bucket existence causes failure");
