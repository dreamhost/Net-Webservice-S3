use strict;
use Test::More tests => 30;
use Net::Webservice::S3;

use HTTP::Request;

my $S3 = Net::Webservice::S3->new(
	access_key => "AKIAIOSFODNN7EXAMPLE",
	secret_key => "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
	host => "s3.amazonaws.com",
);

sub check_sig {
	my (
		$test_name,
		$method, $url, $headers,
		$string_to_sign,
		$signature,
	) = @_;

	my $Req = HTTP::Request->new($method => $url);
	while (my ($k, $v) = splice @$headers, 0, 2) {
		$Req->headers->push_header($k => $v);
	}

	is(
		$S3->_sign_request_string($Req), $string_to_sign,
		"$test_name - StringToSign"
	);

	is(
		$S3->sign_request($Req), $signature,
		"$test_name - signature"
	);

	is(
		$Req->header("Authorization"),
		"AWS $S3->{access_key}:$signature",
		"$test_name - Authorization header"
	);
}


# These test cases are all derived from Amazon's documentation:
# http://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html

check_sig(
	"Example Object GET",
	GET => "http://johnsmith.s3.amazonaws.com/photos/puppy.jpg",
	[
		Date => "Tue, 27 Mar 2007 19:36:42 +0000",
	],
	(
		"GET\n"
		. "\n"
		. "\n"
		. "Tue, 27 Mar 2007 19:36:42 +0000\n"
		. "/johnsmith/photos/puppy.jpg"
	),
	"bWq2s1WEIj+Ydj0vQ697zp+IXMU=",
);


check_sig(
	"Example Object PUT",
	PUT => "http://johnsmith.s3.amazonaws.com/photos/puppy.jpg",
	[
		Date => "Tue, 27 Mar 2007 21:15:45 +0000",
		"Content-Type" => "image/jpeg",
		"Content-Length" => "94328",
	],
	(
		"PUT\n"
		. "\n"
		. "image/jpeg\n"
		. "Tue, 27 Mar 2007 21:15:45 +0000\n"
		. "/johnsmith/photos/puppy.jpg",
	),
	"MyyxeRY7whkBe+bq8fHCL/2kKUg="
);


check_sig(
	"Example List",
	GET => "http://johnsmith.s3.amazonaws.com/?prefix=photos&max-keys=50&marker=puppy",
	[
		Date => "Tue, 27 Mar 2007 19:42:41 +0000",
		"User-Agent" => "Mozilla/5.0",
	],
	(
		"GET\n"
		. "\n"
		. "\n"
		. "Tue, 27 Mar 2007 19:42:41 +0000\n"
		. "/johnsmith/"
	),
	"htDYFYduRNen8P9ZfE/s9SuKy0U="
);


check_sig(
	"Example Fetch",
	GET => "http://johnsmith.s3.amazonaws.com/?acl",
	[
		Date => "Tue, 27 Mar 2007 19:44:46 +0000",
	],
	(
		"GET\n"
		. "\n"
		. "\n"
		. "Tue, 27 Mar 2007 19:44:46 +0000\n"
		. "/johnsmith/?acl"
	),
	"c2WLPFtWHVgbEmeEG93a4cG37dM="
);


check_sig(
	"Example Delete",
	DELETE => "http://s3.amazonaws.com/johnsmith/photos/puppy.jpg",
	[
		Date => "Tue, 27 Mar 2007 21:20:27 +0000",
		"x-amz-date" => "Tue, 27 Mar 2007 21:20:26 +0000",
	],
	(
		"DELETE\n"
		. "\n"
		. "\n"
		. "Tue, 27 Mar 2007 21:20:26 +0000\n"
		. "/johnsmith/photos/puppy.jpg"
	),
	"lx3byBScXR6KzyMaifNkardMwNk="
);


check_sig(
	"Example Upload",
	PUT => "http://static.johnsmith.net:8080/db-backup.dat.gz",
	[
		Date => "Tue, 27 Mar 2007 21:06:08 +0000",
		"x-amz-acl" => "public-read",
		"content-type" => "application/x-download",
		"Content-MD5" => "4gJE4saaMU4BqNR0kLY+lw==",
		"X-Amz-Meta-ReviewedBy" => "joe\@johnsmith.net",
		"X-Amz-Meta-ReviewedBy" => "jane\@johnsmith.net",
		"X-Amz-Meta-FileChecksum" => "0x02661779",
		"X-Amz-Meta-ChecksumAlgorithm" => "crc32",
		"Content-Disposition" => "attachment; filename=database.dat",
		"Content-Encoding" => "gzip",
		"Content-Length" => "5913339",
	],
	(
		"PUT\n"
		. "4gJE4saaMU4BqNR0kLY+lw==\n"
		. "application/x-download\n"
		. "Tue, 27 Mar 2007 21:06:08 +0000\n"
		. "x-amz-acl:public-read\n"
		. "x-amz-meta-checksumalgorithm:crc32\n"
		. "x-amz-meta-filechecksum:0x02661779\n"
		. "x-amz-meta-reviewedby:"
		. "joe\@johnsmith.net,jane\@johnsmith.net\n"
		. "/static.johnsmith.net/db-backup.dat.gz"
	),
	"ilyl83RwaSoYIEdixDQcA4OnAnc="
);


check_sig(
	"Example List All My Buckets",
	GET => "http://s3.amazonaws.com/",
	[
		"Date" => "Wed, 28 Mar 2007 01:29:59 +0000",
	],
	(
		"GET\n"
		. "\n"
		. "\n"
		. "Wed, 28 Mar 2007 01:29:59 +0000\n"
		. "/"
	),
	"qGdzdERIC03wnaRNKh6OqZehG9s="
);


check_sig(
	"Example Unicode Keys",
	GET => "http://s3.amazonaws.com/dictionary/fran%C3%A7ais/pr%c3%a9f%c3%a8re",
	[
		"Date" => "Wed, 28 Mar 2007 01:49:49 +0000",
	],
	(
		"GET\n"
		. "\n"
		. "\n"
		. "Wed, 28 Mar 2007 01:49:49 +0000\n"
		. "/dictionary/fran%C3%A7ais/pr%c3%a9f%c3%a8re"
	),
	"DNEZGsoieTZ92F3bUfSPQcbGmlM="
);


check_sig(
	"Example Query String Request Authentication",
	GET => "http://johnsmith.s3.amazonaws.com/photos/puppy.jpg",
	[
		"Expires" => "1175139620",
	],
	(
		"GET\n"
		. "\n"
		. "\n"
		. "1175139620\n"
		. "/johnsmith/photos/puppy.jpg"
	),
	"NpgCjnDzrM+WFzoENXmpNDUsSn8="
);

# The following test cases are NOT from the Amazon documentation! They test
# edge cases that are only hinted at in the documentation. Tricky, tricky.

# Test two things:
#   1. response-X headers
#   2. some tricky encoding in the header (no %2B for +)
#
# The second bit is to confirm the absence of the bug described at:
# http://stackoverflow.com/q/9051650/

check_sig(
	"response-content-type header",
	GET => "http://example.s3.amazonaws.com/object?response-content-type=image/svg%2Bxml",
	[
		"Expires" => "1378868184",
	],
	(
		"GET\n"
		. "\n"
		. "\n"
		. "1378868184\n"
		. "/example/object?response-content-type=image/svg+xml"
	),
	"/oy0PnUWukjqPRNMmz1YSj3iWhc="
);
