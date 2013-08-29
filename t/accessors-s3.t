use strict;
use Test::More tests => 16;
use Net::Webservice::S3;

my $S3;

$S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
);

ok($S3, "Simple creation");
is($S3->uri->as_string, "https://s3.example.com", "... URI");
is($S3->access_key, undef, "... no access_key");


$S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
	access_key => "access",
	secret_key => "secret",
	ssl => 0,
	ua => "ua",
);

ok($S3, "Complex creation");
is($S3->uri->as_string, "http://s3.example.com", "... URI");
is($S3->access_key, "access", "... access_key");
is($S3->secret_key, "secret", "... secret_key");
is($S3->agent->agent, "ua", "... UA");

is(
	$S3->uri("x")->as_string,
	"http://s3.example.com/x",
	"URI (simple)"
);

is(
	$S3->uri("/a")->as_string,
	"http://s3.example.com//a",
	"URI (leading slash)"
);

is(
	$S3->uri("a//b")->as_string,
	"http://s3.example.com/a//b",
	"URI (double slash)"
);

is(
	$S3->uri("./x/../y")->as_string,
	"http://s3.example.com/./x/../y",
	"URI (non-traversal)"
);

is(
	$S3->uri("x?foo")->as_string,
	"http://s3.example.com/x%3Ffoo",
	"URI (escaping)"
);

is(
	$S3->uri("x", "y")->as_string,
	"http://s3.example.com/x?y",
	"URI (simple query attachment)"
);

is(
	$S3->uri("x", [ y => 1, z => 2 ])->as_string,
	"http://s3.example.com/x?y=1&z=2",
	"URI (query form)"
);

is(
	$S3->uri("x", [ y => "=", z => "?" ])->as_string,
	"http://s3.example.com/x?y=%3D&z=%3F",
	"URI (query form + escaping)"
);
