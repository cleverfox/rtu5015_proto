#!/usr/local/bin/perl
use strict;
use v5.10;
use IO::Handle qw( );  # For autoflush
use Device::SerialPort;
use Mojo::JSON;

my $debug=0;
my $port="/dev/cuaU2";
my $com = new Device::SerialPort ($port, 1);
die "Can't open port" unless $com;

$com->user_msg("ON");
$com->databits(8);
$com->baudrate(9600);
$com->parity("none");
$com->stopbits(1);
$com->handshake("none");

#$com->baudrate(2400);
#$com->parity("odd");

$com->read_char_time(0);    # don't wait for each character
$com->read_const_time(100); # 1 second per unfulfilled "read" call
 
$com->write_settings || undef $com;

my $STALL_DEFAULT=1; # how many seconds to wait for new input
my $timeout=$STALL_DEFAULT;

my $pw="1234";

#say request("STATUS?");
#say request("LOG=ALL?");
foreach(@{req_log()}){
  say(Mojo::JSON::encode_json($_));
};
#
#foreach(@{req_all()}){
#  say(Mojo::JSON::encode_json($_));
#};
#say add_phone(1,"+79102113571");
#say add_phone(3,"+79103111084");
#say request("TELALL?");

$com->close || die "failed to close";
undef $com;

sub req_log {
  my $res=request("LOG=ALL?");
  my @arr;
  foreach(split("\n",$res)){
    if(/^LOGS(\d+):(\d{4})(\d{2})(\d{2})(\d{2})(\d{2}):([^:]+):(.+)/){
      my $date=sprintf("%04d-%02d-%02d %02d:%02d:00",$2,$3,$4,$5,$6);
      push(@arr,[int($1),$date,$7,$8]);
    }
  }
  return [@arr];
}

sub req_all {
  my $res=request("TELALL?");
  my @arr;
  foreach(split("\n",$res)){
    if (/^([01-9])+:(\S+)/){
      push(@arr,[$1,$2]);
    };
  }
  return [@arr];
}

sub req_phone {
  my $slot=shift;
  my $res=request(sprintf("TEL%04d?",$slot));
  if (($res=~/TEL:/) && ($res=~/([01-9])+: (\S+)/ && $1==$slot)){
    return $2;
  };
  return undef;
}

sub add_phone {
  my ($slot,$number)=@_;
  my $res=request(sprintf("TEL%s#%04d",$number,$slot));
  return ($res=~/TEL:/) && ($res=~/([01-9])+: (\S+)/ && $1==$slot && $2 eq $number);
}

sub request {
  my $req = shift;
  do_send($pw."#".$req."#\r");
  return read_resp();
}

sub do_send {
  my $req=shift;
  printf("< %s\n",$req) if ($debug);
  $com->write($req);
}

sub read_resp {
  my $s=0;
  my $flushed=0;
  my $reads=0;
  my $data='';
  while(1){
    my($c,$b)=$com->read(1000);
    if($c){
      $s=3;
      printf("> %s\n",$b) if ($debug);
      $data.=$b;
      $reads++;
    }else{
      if($s-->0){
        #printf(".\n");
        $flushed=1;
      }else{
        $s--;
        last if($reads);
        last if($s<-10);
      }
    }
  }
  return $data;
};
