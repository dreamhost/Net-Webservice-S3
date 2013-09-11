use strict;
use Test::More tests => 4;
use Test::Mock::LWP::Dispatch qw( $mock_ua );
use Net::Webservice::S3;

use HTTP::Request;

my $S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
	ua => $mock_ua,
);

# WARNING: This bit of the test may be fragile... handle with care.
my $xmlin = <<EOF;
<ExampleRequest>
  <Hello>world</Hello>
</ExampleRequest>
EOF

my $xmlout = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<ExampleResult xmlns="http://example.com/12345">
	<Foo attr="value" />
	<Bar>123</Bar>
	<Bar>456</Bar>
	<Baz>
		<Qux />
	</Baz>
</ExampleResult>
EOF

$mock_ua->map("https://s3.example.com/test" => sub {
	my ($req) = @_;
	is($req->method, "POST", "Request method is correct");
	is($req->content, $xmlin, "Request content is correct");
	is($req->header("X-Foo"), "Bar", "Request custom header is correct");
	my $res = HTTP::Response->new(200);
	$res->content($xmlout);
	return $res;
});

my ($code, $result) = $S3->xml_request(
	HTTP::Request->new(
		POST => $S3->uri("test"),
		[ "X-Foo" => "Bar" ],
	),
	{
		ExampleRequest => [{
			Hello => ["world"],
		}],
	}
);

is_deeply($result, {
	ExampleResult => [{
		xmlns => "http://example.com/12345",
		Foo => [{ attr => "value" }],
		Bar => [
			"123",
			"456",
		],
		Baz => [{
			Qux => [{ }],
		}],
	}]
}, "Response is decoded correctly");
