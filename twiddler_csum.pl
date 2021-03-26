#!/usr/bin/perl -w
use strict;

my $sum = 0;

foreach my $line (<STDIN>)
{
  my ($junk, $addr, $data) = split(/[=x]/,$line);
  if (defined($addr) && defined($data))
  {
    chomp $data;
    $data =~ s/\s//g;
#    print "$addr $data\n";
    $addr = hex($addr);
    my @bytes = $data =~ /..?/g;
    if ($addr == 0)
    {
      shift @bytes;
      shift @bytes;
    }
    foreach my $byte (@bytes)
    {
      $sum += hex($byte);
    } 
  }
  $sum %= 65536 if ($sum > 65535);
}
# Two's complement
$sum ^= 65535;
$sum += 1;
$sum %= 65536;
printf("%04X\n", $sum);
