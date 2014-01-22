use strict;
use Fennec::Declare;

use_ok "Net::Webservice::S3";
use_ok "Net::Webservice::S3::Bucket";


my $S3 = Net::Webservice::S3->new(host => "s3.example.com");


tests self_created_bucket {
	my $B = Net::Webservice::S3::Bucket->new($S3, "abc");
	is($B->connection, $S3, "Self-created bucket connection accessor");
	is($B->name, "abc", "Self-created bucket name accessor");
};


tests s3_created_bucket {
	my $B = $S3->bucket("def");
	is($B->connection, $S3, "S3-created bucket connection accessor");
	is($B->name, "def", "S3-created bucket name accessor");
};


tests bucket_accessors {
	my $B = $S3->bucket("bkt");

	is(
		$B->uri("")->as_string,
		"https://s3.example.com/bkt/",
		"Bucket root URI",
	);

	is(
		$B->uri("test")->as_string,
		"https://s3.example.com/bkt/test",
		"Bucket test path URI",
	);

	is(
		$B->uri("test", "query")->as_string,
		"https://s3.example.com/bkt/test?query",
		"Bucket scalar query URI",
	);

	is(
		$B->uri("test", [k1 => "v1", k2 => "v2"])->as_string,
		"https://s3.example.com/bkt/test?k1=v1&k2=v2",
		"Bucket key/val query URI",
	);

	is(
		$B->uri("test", [k1 => "=", k2 => "?"])->as_string,
		"https://s3.example.com/bkt/test?k1=%3D&k2=%3F",
		"Bucket key/val query URI with escaping",
	);
};


done_testing;
