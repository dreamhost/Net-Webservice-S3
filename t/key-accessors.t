use strict;
use Fennec::Declare;

use_ok "Net::Webservice::S3";
use_ok "Net::Webservice::S3::Bucket";
use_ok "Net::Webservice::S3::Key";


my $S3 = Net::Webservice::S3->new(host => "s3.example.com");
my $B = Net::Webservice::S3::Bucket->new($S3, "bucket");


tests self_created_key {
	my $K = Net::Webservice::S3::Key->new($B, "key1");
	is($K->bucket, $B, "Self-created key bucket accessor");
	is($K->name, "key1", "Self-created key key accessor");
	is($K->connection, $S3, "Self-created key connection accessor");
};


tests bucket_created_key {
	my $K = $B->key("key2");
	is($K->bucket, $B, "Bucket-created key bucket accessor");
	is($K->name, "key2", "Bucket-created key key accessor");
	is($K->connection, $S3, "Bucket-created key connection accessor");

	is(
		$K->uri->as_string,
		"https://s3.example.com/bucket/key2",
		"Key URI (simple)"
	);

	is(
		$K->uri("query")->as_string,
		"https://s3.example.com/bucket/key2?query",
		"Key URI (with subresource)"
	);

	is(
		$K->uri([key => "val"])->as_string,
		"https://s3.example.com/bucket/key2?key=val",
		"Key URI (with key-val query)"
	);
};


done_testing;
