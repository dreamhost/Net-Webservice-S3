use strict;
use Fennec::Declare;
use Test::XML;
use HTTP::Request;
use HTTP::Response;


use_ok "Net::Webservice::S3";


my $S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
	retry => 0, # don't retry HTTP 500 tests
);


tests xml_request {
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			is($req->uri, "https://s3.example.com/test", "URI");
			is($req->method, "POST", "method");
			is($req->header("X-Foo"), "Bar", "header");
			is_xml($req->content, q{
				<ExampleRequest>
					<Hello>world</Hello>
				</ExampleRequest>
			}, "request content");

			my $Response = HTTP::Response->new(200);
			$Response->content_type("text/xml");
			$Response->content(q{
				<ExampleResult>
						<Foo attr="value" />
						<Bar>123</Bar>
						<Bar>456</Bar>
						<Baz>
								<Qux />
						</Baz>
				</ExampleResult>
			});
			return $Response;
		},
	);

	my $rdata = $S3->xml_request(
		HTTP::Request->new(
			POST => $S3->uri("test"),
			[ "X-Foo" => "Bar" ],
		),
		data => {
			ExampleRequest => [{
				Hello => ["world"],
			}],
		}
	);

	is_deeply($rdata, {
		ExampleResult => [{
			Foo => [{ attr => "value" }],
			Bar => [ "123", "456" ],
			Baz => [{
				Qux => [{ }],
			}],
		}]
	}, "Response decoded correctly");
};


tests xml_request_calling {
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			my $Res = HTTP::Response->new(200);
			$Res->content_type("text/xml");
			$Res->content(q{
				<ExampleResult />
			});
			return $Res;
		},
	);

	my $req = HTTP::Request->new(GET => $S3->uri("test"));

	my $rdata = $S3->xml_request($req);
	is_deeply($rdata, { ExampleResult => [{}] }, "Non-array call rdata");

	my ($rdata, $res) = $S3->xml_request($req);
	is_deeply($rdata, { ExampleResult => [{}] }, "Array call rdata");
	ok($res->isa("HTTP::Response"), "Array call response");
};


tests http_error {
	my $error_status;
	my $error_content;
	my $error_type;

	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			my $Response = HTTP::Response->new($error_status);
			$Response->content($error_content);
			$Response->content_type($error_type);
			return $Response;
		},
	);

	my $Req = HTTP::Request->new(GET => $S3->uri("/"));
	my $res;

	$error_status = 400;
	$error_content = "Not XML";
	$error_type = "text/plain";
	throws_ok(sub {
		$S3->xml_request($Req)
	}, qr/HTTP 400/, "HTTP error passed to caller");

	# Content type still isn't text/xml, so this shouldn't be parsed!
	$error_content = q{
		<Error>
			<Code>ExampleError</Code>
			<Message>This is an example</Message>
			<Resource>/blah/</Resource>
		</Error>
	};
	throws_ok(sub {
		$S3->xml_request($Req)
	}, qr/HTTP 400/, "HTTP error still passed to caller");

	$error_type = "text/xml";
	throws_ok(sub {
		$S3->xml_request($Req)
	}, qr/ExampleError: This is an example/, "XML error parsed");

	lives_ok(sub {
		$S3->xml_request($Req, error_ok => 1)
	}, "error_ok makes XML errors OK");

	$error_content = "Invalid XML";
	lives_ok(sub {
		$S3->xml_request($Req, error_ok => 1)
	}, "...even when XML is invalid");

	throws_ok(sub {
		$S3->xml_request($Req)
	}, qr/Invalid XML/, "Invalid XML causes exception");

	$error_type = "text/plain";
	lives_ok(sub {
		$S3->xml_request($Req, error_ok => 1)
	}, "Non-XML errors are also acceptable under error_ok");

	$error_status = "500";
	throws_ok(sub {
		$S3->xml_request($Req, error_ok => 1)
	}, qr/HTTP 500/, "...but not 500 errors");

	lives_ok(sub {
		$S3->xml_request($Req, error_ok => 500)
	}, "...unless error_ok is set to 500");
};


done_testing;
