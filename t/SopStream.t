# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl SopCast1.t'

#########################

use Test::More;

BEGIN { 
	use_ok('File::Basename'),
	use_ok('File::Path'),
	use_ok('File::Spec::Functions'),
	use_ok('File::stat'),
	use_ok('Getopt::Long'),
	use_ok('HTML::TreeBuilder'),
	use_ok('IO::Socket'),
	use_ok('LWP::UserAgent'),
	use_ok('Pod::Usage'),
	use_ok('Sys::Hostname'),
	use_ok('XML::Simple'),
};

ok(`which sp-sc` ne '', "Testing for existence of sp-sc");

done_testing();