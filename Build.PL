#!/usr/bin/perl
use strict;
use Module::Build;

Module::Build->new(
	module_name => "Net::Webservice::S3",
	license => "bsd",

	all_from => "Net::Webservice::S3",
	create_readme => 1,

	requires => {
		"perl" => 5.010,
		"Carp" => 0,
		"Digest::HMAC" => 0,
		"Digest::SHA1" => 0,
		"LWP::UserAgent" => 0,
		"POSIX" => 0,
	},

	build_requires => {
	},

	test_requires => {
		"Fennec" => "2.009",
		"Fennec::Declare" => "1.000",
		"Test::XML" => 0,
	},

	meta_merge => {
		resources => {
			repository => "https://github.com/andfarm/Net-Webservice-S3",
			homepage => "https://github.com/andfarm/Net-Webservice-S3",
			bugtracker => "https://github.com/andfarm/Net-Webservice-S3/issues",
		},
	},

)->create_build_script();

