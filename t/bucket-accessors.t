use strict;
use Test::More tests => 9;
use Net::Webservice::S3;
use Net::Webservice::S3::Bucket;

my $S3 = Net::Webservice::S3->new(
    host => "s3.example.com",
);

my $B;

$B = Net::Webservice::S3::Bucket->new($S3, "abc");
is($B->connection, $S3, "Self-created bucket connection accessor");
is($B->name, "abc", "Self-created bucket name accessor");

$B = $S3->bucket("def");
is($B->connection, $S3, "S3-created bucket connection accessor");
is($B->name, "def", "S3-created bucket name accessor");

is(
    $B->uri("")->as_string,
    "https://s3.example.com/def/",
    "Bucket root URI",
);

is(
    $B->uri("test")->as_string,
    "https://s3.example.com/def/test",
    "Bucket test path URI",
);

is(
    $B->uri("test", "query")->as_string,
    "https://s3.example.com/def/test?query",
    "Bucket scalar query URI",
);

is(
    $B->uri("test", [k1 => "v1", k2 => "v2"])->as_string,
    "https://s3.example.com/def/test?k1=v1&k2=v2",
    "Bucket key/val query URI",
);

is(
    $B->uri("test", [k1 => "=", k2 => "?"])->as_string,
    "https://s3.example.com/def/test?k1=%3D&k2=%3F",
    "Bucket key/val query URI with escaping",
);
