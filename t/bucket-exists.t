use strict;
use Fennec::Declare;

use_ok "Net::Webservice::S3";


my $S3 = Net::Webservice::S3->new(host => "s3.example.com");


tests bucket_exists {
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			is($req->method, "HEAD", "Request is HEAD");
			if (my ($code) = $req->uri =~ m{^\Qhttps://s3.example.com/\Ehttp(\d+)/$}) {
				ok(1, "Request URI");
				return HTTP::Response->new($code);
			} else {
				ok(0, "Request URI");
				diag("Got: " . $req->uri);
				return HTTP::Response->new(500); # ..!
			}
		},
	);

	ok( $S3->bucket("http200")->exists(), "Bucket exists with HTTP OK");
	ok( $S3->bucket("http403")->exists(), "Bucket exists with HTTP Forbidden");
	ok(!$S3->bucket("http404")->exists(), "Bucket DNE with HTTP Not Found");
};


done_testing;
