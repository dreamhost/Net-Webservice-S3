use strict;
use Test::More tests => 2;
use Test::Exception;
use Test::Mock::LWP::Dispatch qw( $mock_ua );
use Net::Webservice::S3;

my $S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
	ua => $mock_ua,
);

my $B;

$mock_ua->map("https://s3.example.com/bucket/" => sub {
	my ($req) = @_;
	is($req->method, "DELETE", "Request for bucket destroy is DELETE");
	return HTTP::Response->new(204);
});

$B = $S3->bucket("bucket");
ok($B->destroy(), "Bucket destroyed");
