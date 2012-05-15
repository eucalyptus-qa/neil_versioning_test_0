#!/usr/bin/perl

use URI;

sub failure {
  my($msg) = @_;
  print "[TEST_REPORT]\tFAILED: ", $msg, "\n";
  exit(1);
}

sub success {
  my($msg) = @_;
  print "[TEST_REPORT]\t", $msg, "\n";
}

sub make_bucket {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket) = @_;
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --put /dev/null -- --include $s3_url/$bucket";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
  }
  close(RFH);
}

sub cleanup_bucket {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket) = @_;
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --del $s3_url/$bucket";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
  }
  close(RFH);
}

sub enable_versioning {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket) = @_;
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --put ./versioningenabled.txt $s3_url/$bucket?versioning";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
  }
  close(RFH);
}

sub disable_versioning {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket) = @_;
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --put ./versioningdisabled.txt $s3_url/$bucket?versioning";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
  }
  close(RFH);
}


sub put_object {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object) = @_;
  $version_id = "false";
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --put ./testobject -- -i $s3_url/$bucket/$object";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
    if($_ =~ /x-amz-version-id: (.*)\r\n/) {
      $version_id = $1;
    }
  }
  close(RFH);
  return $version_id;
}

sub head_versioned_object {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object, $version_id) = @_;
  $returned_version_id = "false";
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --head -- --include $s3_url/$bucket/$object?versionId=$version_id";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
    if($_ =~ /x-amz-version-id: (.*)\r\n/) {
      $returned_version_id = $1;
    }
  }
  close(RFH);
  if($returned_version_id =~ /false/) {
    failure("versioned HEAD failed on ", $bucket, "/", $object);
  }
}

sub get_object {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object) = @_;
  $etag = "false";
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key -- --include $s3_url/$bucket/$object";
  if(!open GETRESULT, ">getunversionedobjecttest") {
    failure("Unable to open output file for writing (Unversioned GET)");
  }
  open(RFH, "$cmd|");
  while(<RFH>) {
    if($_ =~ /ETag: (.*)\r\n/) {
      $etag = $1;
    }
    print GETRESULT $_;
  }
  close(GETRESULT);
  close(RFH);
  if($etag =~ /false/) {
    failure("unversioned GET failed on ", $bucket, "/", $object);
  }
}

sub get_versioned_object {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object, $version_id) = @_;
  $returned_version_id = "false";
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key -- --include $s3_url/$bucket/$object?versionId=$version_id";
  if(!open GETRESULT, ">getobjecttest") {
    failure("Unable to open output file for writing (Versioned GET)");
  }
  open(RFH, "$cmd|");
  while(<RFH>) {
    if($_ =~ /x-amz-version-id: (.*)\r\n/) {
      $returned_version_id = $1;
    }
    print GETRESULT $_;
  }
  close(GETRESULT);
  close(RFH);
  if($returned_version_id =~ /false/) {
    failure("versioned GET failed on ", $bucket, "/", $object);
  }
}

sub delete_object {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object) = @_;
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --del -- --include $s3_url/$bucket/$object";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
    if($_ =~ /Error/) {
      failure("unversioned DELETE failed on ", $bucket, "/", $object);
    }
  }
  close(RFH);
}

sub delete_versioned_object {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object, $version_id) = @_;
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --del -- --include $s3_url/$bucket/$object?versionId=$version_id";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
    if($_ =~ /Error/) {
      failure("unversioned DELETE failed on ", $bucket, "/", $object);
    }
  }
  close(RFH);
}

sub restore_object {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object, $version_id) = @_;
  $copy_source_string = "/$bucket/$object?versionId=$version_id";
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key --copySrc \"$copy_source_string\" --put /dev/null -- --include $s3_url/$bucket/$object";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
  }
  close(RFH);
}


sub list_versions {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket) = @_;
  $cmd = "$s3curl_home/s3curl.pl --endpoint $s3_host --id $id --key $key -- --include $s3_url/$bucket?versions | xmlindent ";
  open(RFH, "$cmd|");
  while(<RFH>) {
    print $_;
  }
  close(RFH);
}


sub test_basic_versioning {
  my($s3_host, $s3curl_home, $id, $key, $s3_url, $bucket, $object) = @_;
  $version_id = put_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');
  head_versioned_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00', $version_id);
  get_versioned_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00', $version_id);
  delete_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');
  delete_versioned_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00', $version_id);
}

sub versioning_test_0 {
  my($s3_host, $s3curl_home, $id, $key, $s3_url) = @_;
  make_bucket($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');
  enable_versioning($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');

  test_basic_versioning($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');
  test_basic_versioning($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');

  disable_versioning($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');

  list_versions($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');
  cleanup_bucket($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');
}

sub versioning_test_1 {
  my($s3_host, $s3curl_home, $id, $key, $s3_url) = @_;
  make_bucket($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');
  enable_versioning($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');

  $version_id = put_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');
  delete_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');
  #restore object
  restore_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00', $version_id);
  get_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');
  delete_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00');
  delete_versioned_object($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007', 'testobject00', $version_id);

  disable_versioning($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');
  list_versions($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');
  cleanup_bucket($s3_host, $s3curl_home, $id, $key, $s3_url, 'testbucketversioning0007');
}

my $s3_url = URI->new($ENV{'S3_URL'});
$s3_host = $s3_url->host();

failure("Unable to get S3 host. Is S3_URL set?") unless defined $s3_host;

my $ec2_url = URI->new($ENV{'EC2_URL'});
$ec2_host = $ec2_url->host();

failure("Unable to get EC2_URL host. Is EC2_URL set?") unless defined $ec2_host;


$s3curl_home = $ENV{'S3_CURL_HOME'};
$id = $ENV{'EC2_ACCESS_KEY'};
$key = $ENV{'EC2_SECRET_KEY'};
$s3_url = $ENV{'S3_URL'};

failure("S3_CURL_HOME must be set.") unless defined $s3curl_home;
failure("EC2_ACCESS_KEY must be set.") unless defined $id;
failure("EC2_SECRET_KEY must be set.") unless defined $key;
failure("S3_URL must be set.") unless defined $s3_url;

versioning_test_0($s3_host, $s3curl_home, $id, $key, $s3_url);
versioning_test_1($s3_host, $s3curl_home, $id, $key, $s3_url);

exit(0);
