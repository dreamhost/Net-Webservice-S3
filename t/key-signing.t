use strict;
use Fennec::Declare;

use_ok "Net::Webservice::S3";


my $S3 = Net::Webservice::S3->new(
	access_key => "AKIAIOSFODNN7EXAMPLE",
	secret_key => "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
	host => "s3.amazonaws.com",
);


tests signed_uri {
	my $Key = $S3->bucket("johnsmith")->key("photos/puppy.jpg");
	my $signed_uri = $Key->signed_uri(expire => 1175139620);
	is($signed_uri->query, "AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE&Signature=NpgCjnDzrM%2BWFzoENXmpNDUsSn8%3D&Expires=1175139620", "Query string matches");
};


done_testing;
