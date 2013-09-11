use strict;
use Test::More;
use Test::Mock::LWP::Dispatch qw( $mock_ua );
use Net::Webservice::S3;

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

$mock_ua->map("https://s3.example.com/test/this%3Fnot-a-query?query" => sub {
	my ($req) = @_;
	is($req->method, "POST", "Request method is correct");
	is($req->content, $xmlin, "Request content is correct");
	my $res = HTTP::Response->new(200);
	$res->content($xmlout);
	return $res;
});

my ($code, $result) = $S3->xml_request({
	ExampleRequest => [{
		Hello => ["world"],
	}],
}, POST => "test/this?not-a-query", "query");
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
