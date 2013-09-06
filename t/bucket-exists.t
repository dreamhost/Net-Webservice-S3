use strict;
use Test::More tests => 6;
use Test::Mock::LWP::Dispatch qw( $mock_ua );
use Net::Webservice::S3;
use Net::Webservice::S3::Bucket;

my $S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
	ua => $mock_ua,
);

for my $code (200, 403, 404) {
	$mock_ua->map(
		"https://s3.example.com/bucket_$code/" => sub {
			my ($req) = @_;
			is($req->method, "HEAD", "Request for bucket $code is HEAD");
			return HTTP::Response->new($code);
		}
	);
}

ok( $S3->bucket("bucket_200")->exists(), "Bucket exists with HTTP OK");
ok( $S3->bucket("bucket_403")->exists(), "Bucket exists with HTTP Forbidden");
ok(!$S3->bucket("bucket_404")->exists(), "Bucket DNE with HTTP Not Found");

