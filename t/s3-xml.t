use strict;
use Fennec::Declare;
use Test::XML;
use HTTP::Request;
use HTTP::Response;


use_ok "Net::Webservice::S3";


my $S3 = Net::Webservice::S3->new(host => "s3.example.com");


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
			Foo => [{ attr => "value" }],
			Bar => [ "123", "456" ],
			Baz => [{
				Qux => [{ }],
			}],
		}]
	}, "Response decoded correctly");
};


done_testing;
