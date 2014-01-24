use strict;
use Fennec::Declare;
use HTTP::Response;

use_ok "Net::Webservice::S3";


my $S3 = Net::Webservice::S3->new(host => "s3.example.com");


tests list_buckets {
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			is($req->uri, "https://s3.example.com", "URI");
			is($req->method, "GET");
			my $Response = HTTP::Response->new(200);
			$Response->header("Content-Type" => "text/xml");
			$Response->content(q{<?xml version="1.0" encoding="UTF-8"?>
				<ListAllMyBucketsResult>
					<Owner>
						<ID>bcaf1ffd86f461ca5fb16fd081034f</ID>
						<DisplayName>webfile</DisplayName>
					</Owner>
					<Buckets>
						<Bucket>
							<Name>quotes</Name>
							<CreationDate>2006-02-03T16:45:09.000Z</CreationDate>
						</Bucket>
						<Bucket>
							<Name>samples</Name>
							<CreationDate>2006-02-03T16:41:58.000Z</CreationDate>
						</Bucket>
					</Buckets>
				</ListAllMyBucketsResult>
			});
			return $Response;
		},
	);

	my @res = $S3->buckets;
	is_deeply([@res], [map { $S3->bucket($_) } qw( quotes samples )],
		"Buckets in response are right"
	);
};


done_testing;
