use strict;
use Fennec::Declare;

use_ok "Net::Webservice::S3";


my $S3 = Net::Webservice::S3->new(host => "s3.example.com");


tests destroy_bucket {
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			is($req->uri, "https://s3.example.com/destroyme/", "right URI");
			is($req->method, "DELETE", "right method");
			return HTTP::Response->new(204);
		},
	);

	my $B = $S3->bucket("destroyme");
	ok($B->destroy(), "Bucket destroyed");
};


done_testing;
