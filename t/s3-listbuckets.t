use strict;
use Test::More tests => 2;
use Test::Mock::LWP::Dispatch qw( $mock_ua );
use Net::Webservice::S3;

my $S3 = Net::Webservice::S3->new(
	host => "s3.example.com",
	ua => $mock_ua,
);

my $xml = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<ListAllMyBucketsResult xmlns="http://doc.s3.amazonaws.com/2006-03-01">
  <Owner>
    <ID>bcaf1ffd86f461ca5fb16fd081034f</ID>
    <DisplayName>webfile</DisplayName>
  </Owner>
  <Buckets>
    <Bucket>
      <Name>quotes</Name>
      <CreationDate>2006-02-03T16:45:09.000Z</CreationDate>
    </Bucket>
    <Bucket>
      <Name>samples</Name>
      <CreationDate>2006-02-03T16:41:58.000Z</CreationDate>
    </Bucket>
  </Buckets>
</ListAllMyBucketsResult>
EOF

$mock_ua->map("https://s3.example.com" => sub {
	my ($req) = @_;
	is($req->method, "GET", "Request for bucket list is GET");
	my $res = HTTP::Response->new(200);
	$res->content($xml);
	return $res;
});

my @res = $S3->buckets;
is_deeply([@res], [map { $S3->bucket($_) } qw( quotes samples )],
	"Buckets in response are right"
);
