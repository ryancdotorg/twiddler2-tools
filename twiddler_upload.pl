#!/usr/bin/perl -w
use strict;
use Time::HiRes qw(sleep usleep);
use Fcntl; 

my $DEV = '/dev/ttyS0';

#setserial /dev/ttyS0 spd_cust baud_base 115200 divisor 4
#stty -F /dev/ttyS0 icrnl 38400

# Enable autoflush
$| = 1;
# Assume that the device is already set up...
sysopen(TTYIN, $DEV, O_RDWR | O_NDELAY | O_NOCTTY)
#sysopen(TTYIN, $DEV, O_RDWR | O_NOCTTY)
# (O_NOCTTY no longer needed on POSIX systems)
  or die "can't open $DEV: $!";
open(TTYOUT, "+>&TTYIN")
  or die "can't dup TTYIN: $!";

sub tty_readline
{
  # Wait for data to be recived before trying to read
  sleep 0.010;
  my $buf = '';
  while ($buf !~ /\n/s)
  {
    my $b = '';
    my $rv = sysread(TTYIN, $b, 32);
    if(defined($rv))
    {
      $buf .= $b;
    } else {
      # delay on empty reads so as not to consume all the cpu
      usleep 90;
    }
  }
  return $buf;
}

syswrite(TTYOUT, 'V', 1);
print 'V';
print tty_readline();
syswrite(TTYOUT, 'PTwiddler', 9);
print tty_readline();
my $blk = "";
my $cnt = 0;

foreach my $line (<STDIN>)
{
  my ($junk, $addr, $data) = split(/[=x]/,$line);
  if (defined($addr) && defined($data))
  {
    chomp $data;
    $addr =~ s/\s//g;
    $data =~ s/\s//g;
    print "0x$addr=$data\n";
    $blk .= pack('H*', $data);
    $cnt++;
    if ($cnt == 4)
    {
      syswrite(TTYOUT, 'L' . $blk, 33);
      if (tty_readline() ne "L\n")
      {
        die "bad response from twiddler";
      }
      $cnt = 0;
      $blk = "";
    }
  }
}
print "D\n";
syswrite(TTYOUT, 'D', 1);
print tty_readline();
#for (my $i = 0; $i < 8192; $i += 8)
#{
#  my $addr = sprintf("%04x", $i);
#  print TTYOUT 'R' . uc($addr);
#  print '0x' . $addr;
#  print_tty();
#}
