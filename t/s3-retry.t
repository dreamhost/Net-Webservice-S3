use strict;
use Fennec::Declare;
use HTTP::Request;
use HTTP::Response;


use_ok "Net::Webservice::S3";


describe basic_retry {
	my @resqueue;
	qtakeover "LWP::UserAgent" => (
		request => sub {
			my ($ua, $req) = @_;
			if (my $res = shift @resqueue) {
				return $res;
			} else {
				die "Ran out of responses! (Too many requests?)";
			}
		},
	);

	before_each flush_resqueue {
		@resqueue = ();
	};

	after_each empty_resqueue {
		ok(!@resqueue, "(response queue drained)");
	};

	my $S3 = Net::Webservice::S3->new(
		host => "s3.example.com",
		retry => 2,
		retry_delay => 0,
	);

	tests initial_success {
		@resqueue = (
			HTTP::Response->new(200),
		);

		is($S3->run_request(HTTP::Request->new(
			GET => $S3->uri("/"),
		))->code, 200, "No retry when not needed");
	};

	tests near_maximum_retries {
		@resqueue = (
			HTTP::Response->new(500),
			HTTP::Response->new(500),
			HTTP::Response->new(200),
		);

		is($S3->run_request(HTTP::Request->new(
			GET => $S3->uri("/"),
		))->code, 200, "Request performs expected retry");
	};

	tests maximum_retries {
		@resqueue = (
			HTTP::Response->new(500),
			HTTP::Response->new(500),
			HTTP::Response->new(500),
		);

		throws_ok(sub {
			$S3->run_request(HTTP::Request->new(
				GET => $S3->uri("/"),
			))
		}, qr{HTTP 500}, "Request fails after running out of retries");
	};

	tests suppress_retry {
		@resqueue = (
			HTTP::Response->new(500),
		);
		my $res = $S3->run_request(
			HTTP::Request->new(GET => $S3->uri("/")),
			error_ok => 1,
		);
		ok($res, "Request didn't fail");
		is($res->code, 500, "Response is error");
	};
};


done_testing;
