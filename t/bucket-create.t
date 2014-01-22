use strict;
use Fennec::Declare;
use Test::XML;

use_ok "Net::Webservice::S3";


my $S3 = Net::Webservice::S3->new(host => "s3.example.com");


tests create_ok {
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			is($req->uri, "https://s3.example.com/createme/", "right URI");
			is($req->method, "PUT", "right method");
			is_xml($req->content, q{
				<CreateBucketConfiguration></CreateBucketConfiguration>
			}, "right content");
			return HTTP::Response->new(200);
		},
	);

	my $B = $S3->bucket("createme");
	ok($B->create(), "Bucket created");
};


tests create_403 {
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			is($req->uri, "https://s3.example.com/taken/", "right URI");
			return HTTP::Response->new(403);
		},
	);

	my $B = $S3->bucket("taken");
	dies_ok(sub { $B->create() }, "Bucket not created");
};


done_testing;
