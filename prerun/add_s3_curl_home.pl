#!/usr/bin/perl

system("echo \"export S3_CURL_HOME=/home/test-server/test_share/client-tools/s3-curl\" >> ../credentials/eucarc");

my $rc = $? >> 8;

if( $rc == 1) {
	exit(1);
};

exit(0);

