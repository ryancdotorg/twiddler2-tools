#!/usr/bin/perl -w
use strict;
use Fcntl; 

use Time::HiRes qw(sleep usleep);

my $DEV = '/dev/ttyS0';

# Enable autoflush
$| = 1;
# Assume that the port is already set up...
sysopen(TTYIN, $DEV, O_RDWR | O_NONBLOCK)
  or die "can't open $DEV: $!";
open(TTYOUT, "+>&TTYIN")
  or die "can't dup TTYIN: $!";

# Set up select
my $rin = '';
vec($rin,fileno(TTYIN),1) = 1;

sub tty_readline
{
  my $buf = '';
  while ($buf !~ /\n/s)
  {
    # wait until there is data to read
    select($rin, undef, undef, 1);
    my $b = '';
    my $rv = sysread(TTYIN, $b, 1);
    if(defined($rv))
    {
      $buf .= $b;
    }
  }
  return $buf;
}

syswrite(TTYOUT, 'V', 1);
if (tty_readline() =~ /=(\d{2})\n/s)
{
  print "# Twiddler Firmware Version $1\n";
} else {
  die "bad response from twiddler";
}
for (my $i = 0; $i < 8192; $i += 8)
{
  my $addr = sprintf("%04x", $i);
  syswrite(TTYOUT, 'R' . uc($addr), 5);
  print '0x' . $addr;
  my $reply = tty_readline();
  chomp $reply;
  $reply =~ s/=([0-9A-F]{4})([0-9A-F]{4})([0-9A-F]{4})([0-9A-F]{4})/$1 $2 $3 $4/;
  print " = $reply\n";
}
