#!/usr/bin/perl -w
# vim: ts=2 sw=2 et ai si
use strict;
use Fcntl; 

{ # Start TwidEEPROM
####################

package TwidEEPROM;

my %m1 = ( 'O' => 0,
           'L' => 1,
           'M' => 2,
           'R' => 3,
           '0' => 0,
           'S' => 1,
           'N' => 2,
           'F' => 3, );

my @m2 = ['O', 'L', 'M', 'R'];
my @m3 = ['0', 'S', 'N', 'F'];

sub new
{
  my $self = {};
  my @data;
  foreach my $i (0..8191)
  {
    $data[$i] = 0;
  }
  $self->{DATA} = \@data;
  bless($self);
  return $self;
}

# Write an 8 bit value
sub _w8
{
  my $self = shift;
  my $addr = int(shift);
  my $data  = int(shift);

  die "Bad address: $addr\n" if ($addr < 2 || $addr > 8191);
  die "Bad data: $data\n"    if ($data < 0 || $data > 255);

  $self->{DATA}->[$addr] = $data;
  return 1;
}

# Write a 16 bit value
sub _w16
{
  my $self = shift;
  my $addr = int(shift);
  my $data  = int(shift);

  die "Bad address: $addr\n" if ($addr < 2 || $addr > 8190);
  die "Bad data: $data\n"    if ($data < 0 || $data > 65535);
  $self->{DATA}->[$addr] = $data >> 8;
  $self->{DATA}->[$addr+1] = $data % 256;

  return 1;
}

# Read an 8 bit value
sub _r8
{
  my $self = shift;
  my $addr = int(shift);

  die "Bad address: $addr\n" if ($addr < 0 || $addr > 8191);

  return $self->{DATA}->[$addr];
}

sub _r16
{
  my $self = shift;
  my $addr = int(shift);

  die "Bad address: $addr\n" if ($addr < 0 || $addr > 8190);
  return ($self->{DATA}->[$addr] << 8) + $self->{DATA}->[$addr+1];

  return 1;
}

sub _key2addr
{
  my @keys = split(//,uc(shift));

  #print join(':', @keys) . "\n";

  my $addr = 0;
  if ($#keys < 3 || $#keys > 4)
  { die "Invalid length for _key2addr!\n"; }

  foreach my $k (@keys)
  { die "Invalid key for _key2addr!\n" unless (defined($m1{$k})); }

  # If 5 keys...
  $addr = 512 * $m1{shift(@keys)} if ($#keys == 4);
  $addr += $m1{$keys[0]} << 1;
  $addr += $m1{$keys[1]} << 3;
  $addr += $m1{$keys[2]} << 5;
  $addr += $m1{$keys[3]} << 7;

  return $addr;
}

sub get_chord
{
  my $self = shift;
  my $addr = _key2addr(shift);

  return $self->_r16($addr);
}

sub print_chord
{
  my $self = shift;
  my $key  = shift;
  my $addr = _key2addr($key);

  printf("%s: 0x%04X\n", $key, $self->get_chord($key));
  return 1;
}

sub unmap_chord
{
  my $self = shift;
  my $addr = _key2addr(shift);

  return $self->_w16($addr, 0);
}

sub default_chord
{
  my $self = shift;
  my $addr = _key2addr(shift);

  return $self->_w16($addr, 65535);
}

sub set_chord
{
  my $self = shift;
  my $addr = _key2addr(shift);
  my $data = shift;
  my $data2 = shift;

  if (defined($data) && defined($data2) && length($data) >= 1 &&
      length($data2) >= 1 && length($data) <= 63 && length($data2) <= 63)
  {
    $data  = chr(length($data)) . $data;
    $data .= chr(length($data2)) . $data2;
    $self->_w16($addr, $self->_write_scan($data));
    return 1;
  }
  elsif (length($data) == 1)
  {
    $self->_w16($addr, ord($data));
    # Automaticly generate shift mappings 
    if ($addr < 0x200 && $data ge 'a' && $data le 'z')
    {
      $self->_w16(0x200 + $addr, ord(uc($data)));
    }
    return 1;
  }
  elsif (length($data) > 1 && length($data) <= 127)
  {
    $data = chr(0x80 + length($data)) . $data;
    $self->_w16($addr, $self->_write_scan($data));
    return 1;
  } #end if

  print STDERR "Didn't understand set_chord call\n";

  return 0;
}

sub _write_scan
{
  my $self = shift;
  my $data = shift;

  # Split the string into an array of bytes
  my @bytes = split(//,$data);

  my $addr = 0x0830;
  my $okay = 0;

##  print "Looking for free block...\n";
  until ($okay || $addr > 0x1ffc)
  {
    # Find a zero'd byte
    while ($self->_r8($addr) != 0) { $addr++; }
    $okay = 1;
    # Look ahead for enough space
##    printf("Found zero byte at 0x%04x ...\n", $addr);
    foreach my $i ($addr..($addr + $#bytes))
    {
      if ($self->_r8($i) != 0)
      {
##        printf("Not enough free bytes at 0x%04x ...\n", $addr);
        $addr = $i;
        $okay = 0;
        last;
      }
    } # end foreach
  } # end until
  die "Custom scan code memory full!\n" unless ($okay);
  
##  printf("Using 0x%04x ...\n", $addr);

  foreach my $i (0..$#bytes)
  {
    $self->_w8($addr + $i, ord($bytes[$i]));
  }

  return $addr;
}

sub read_ini
{
  my $self = shift;
  my $filename = shift;
  open(INI_IN, '<', $filename)
    or die("Could not open $filename for reading: $!");

  foreach my $line (<INI_IN>)
  {
    my ($key,$data);
    chomp $line;
    # Parse the file
    if ($line =~ /([0OoNnFfSs])\w* \s+ ([0OoLlMmRr]{4}) \s+ = \s+ "([^"]+)"/x)
    {
      $key = "$1$2";
      $data = $3;
      $data = "\\" if ($data eq "\\\\");
      $self->set_chord($key, $data);
      #print "PN (set) $key: $data\n";
    }
    elsif ($line =~ /([0OoNnFfSs])\w* \s+ ([0OoLlMmRr]{4}) \s+ = \s+ (\S+)/x)
    {
      $key = "$1$2";
      $data = $3;
      print "PS $key: $data\n";
    }
  }

  close(INI_IN);
  print "Loaded $filename successfully.\n";
}

sub read_dump
{
  my $self = shift;
  my $filename = shift;
  open(DUMP_IN, '<', $filename)
    or die("Could not open $filename for reading: $!");

  my $sum = 0;

  foreach my $line (<DUMP_IN>)
  {
    my ($junk, $addr, $data) = split(/[=x]/,$line);
    if (defined($addr) && defined($data))
    {
      chomp $data;
      $data =~ s/\s//g;
      $addr = hex($addr);
      my @bytes = $data =~ /..?/g;

      # Load the data into the array
      foreach (0..7) {$self->{DATA}->[$addr+$_] = hex($bytes[$_]);}
    }
  }

  close(DUMP_IN);
  print "Loaded $filename successfully.\n";
}

sub update_csum
{
  my $self = shift; 

  my $sum = 0;

  foreach my $addr (2..8191)
  {
    $sum += $self->_r8($addr);
    
    # Make sure $sum doesn't get too large...
    $sum %= 65536 if ($sum > 65535);
  }

  # Calculate two's complement checksum
  $sum ^= 65535;
  $sum += 1;
  $sum %= 65536;

  # Save the checksum bytes
  $self->{DATA}->[0] = $sum >> 8;
  $self->{DATA}->[1] = $sum % 256;

  return $sum;
}

sub print
{
  my $self = shift;

  $self->update_csum();

  for (my $i = 0; $i < 8192; $i += 8)
  {
    my $addr = sprintf("%04x", $i);
    printf("0x%04x = %04X %04X %04X %04X\n",
           $i, $self->_r16($i), $self->_r16($i+2),
           $self->_r16($i+4), $self->_r16($i+6));
  }
}

####################
} # End TwidEEPROM #

my $o = new TwidEEPROM;
$o->read_dump('./twiddler.dump');
# Clear chord memory

foreach my $i (0x0002..0x07ff)
{
  $o->_w8($i, 0);
}

# Clear custom scan code memory
foreach my $i (0x0830..0x1fff)
{
  $o->_w8($i, 0);
}

$o->read_ini('./tabspace.ini');

# The parser doesn't yet know how to deal with the special keystrokes, so I
# just map them manually

$o->set_chord('l000', "\x09"); # Tab
$o->set_chord('m000', "\x20"); # Space
$o->set_chord('r000', "\x08"); # Backspace

$o->set_chord('l00l', "\"");   # double quote
$o->set_chord('lm00', "\x0D"); # Enter

$o->set_chord('fr000', "\x7F"); # Del
$o->set_chord('fm000', "\x00"); # Null.. How is this sent?
$o->set_chord('fl000', "\x1B"); # Escape

$o->set_chord('f0m00', "\x06"); # Up
$o->set_chord('f00m0', "\x07"); # Down
$o->set_chord('f0r00', "\x0B"); # Left
$o->set_chord('f0l00', "\x0C"); # Right

$o->set_chord('f00r0', "\x04"); # Page Up
$o->set_chord('f000r', "\x05"); # Page Down

$o->set_chord('f00l0', "\x02"); # Home
$o->set_chord('f000l', "\x03"); # End
$o->set_chord('f000m', "\x01"); # Ins

$o->set_chord('flm00', "\x0A"); # Linefeed

$o->set_chord('frr00', "\x80"); # F1
$o->set_chord('frm00', "\x81"); # F2
$o->set_chord('frl00', "\x82"); # F3
$o->set_chord('fr0r0', "\x83"); # F4
$o->set_chord('fr0m0', "\x84"); # F5
$o->set_chord('fr0l0', "\x85"); # F6
$o->set_chord('fr00r', "\x86"); # F7
$o->set_chord('fr00m', "\x87"); # F8
$o->set_chord('fr00l', "\x88"); # F9
$o->set_chord('frrr0', "\x89"); # F10
$o->set_chord('frmm0', "\x8A"); # F11
$o->set_chord('frll0', "\x8B"); # F12

$o->set_chord('n00mm', "\x18"); # CAPS_LOCK
$o->set_chord('n00rr', "\x19"); # NUM_LOCK
$o->set_chord('n00ll', "\x1A"); # SCROLL_LOCK

#$o->set_chord('nl000', "\xE0\x1F\x4B", "\xF0\x4B\xE0\xF0\x1F"); # Win + L

$o->print();
