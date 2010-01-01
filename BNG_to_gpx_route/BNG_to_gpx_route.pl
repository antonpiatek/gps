#!/usr/bin/perl
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Geo::Coordinates::OSGB qw(grid_to_ll shift_ll_into_WGS84);
use XML::Writer;
use IO::File;
use Getopt::Long;

my %opts;
process_options(\%opts);

#get a description
my $desc="";
while(!$desc)
{
  print STDERR "Enter a description\n";
  $desc= <>;
  chomp $desc;
}

#get waypoints
my @waypoints = read_waypoints();
print STDERR "building a route from ".@waypoints." waypoints\n";
print STDERR  map { "  ".@$_[1].",  '".@$_[0]."'\n" } @waypoints;
print STDERR "\n";

#Now write xml
my $output;
my $gps;
my $writer;
if( $opts{file} )
{
  $output = new IO::File( $opts{file}, "w" );
  $writer = new XML::Writer(DATA_MODE => 1, DATA_INDENT => 1, OUTPUT => $output, ENCODING => "utf-8");
}
elsif ( $opts{gps} )
{
  $writer = new XML::Writer(DATA_MODE => 1, DATA_INDENT => 1, OUTPUT => \$gps, ENCODING => "utf-8");
}
else
{
  $writer = new XML::Writer(DATA_MODE => 1, DATA_INDENT => 1, ENCODING => "utf-8");
}
 
#start the xml
$writer->xmlDecl();
#gpx start tag - can the gpsbabel or garmin etrex handle version 1.1? I get 1.0 out of it and gpsbabel...
$writer->startTag("gpx",
                  "version"            => "1.0",
                  "creator"            => "MyScript",
                  "xmlns:xsi"          => "http://www.w3.org/2001/XMLSchema-instance",
                  "xmlns"              => "http://www.topografix.com/GPX/1/0",
                  "xsi:schemaLocation" => "http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd",
                );

  $writer->startTag("rte"); #start route
    $writer->startTag("name");
      $writer->characters($desc);
    $writer->endTag("name");
    #write waypoints on routw
    foreach my $wpt (@waypoints)
    {
      my @waypoint = @$wpt;
      my ($lat, $lon) = shift_ll_into_WGS84( grid_to_ll($waypoint[1]) );
      $writer->startTag("rtept",
                        lat=>$lat,
                        lon=>$lon,
                        );

        $writer->startTag("name");
          $writer->characters($waypoint[0]);
        $writer->endTag("name");
      $writer->endTag("rtept");
    }
  $writer->endTag("rte");
$writer->endTag("gpx");
$writer->end();

#if we are writing a file, do that
if( $opts{file} )
{
  $output->close();
}
#finally if we are supposed to write direct to the gps, then do it
if( $opts{gps} )
{
  print STDERR "sending data to gps via gpsbabel\n";
  my $cmd =  "gpsbabel -r -i gpx -f - -o ".$opts{gps}." -F ".$opts{gps_device};
  open my $GPSBABEL, "|$cmd" or die "can't invoke gpsbabel: $!\n command was '$cmd'\n";
  print $GPSBABEL $gps;
  close $GPSBABEL  or die "error running gpsbabel:\n $!\n $?\n command was '$cmd'\n";;
  print STDERR "done ok :)\n";
}
exit(0);




sub read_waypoints
{
  my @waypoints;
  print STDERR "Enter waypoints, one per line in space separated BNG chunks followed by a description, i.e. \n";
  print STDERR "SU 31577 02523 start\n";
  print STDERR "SU 314 024 waypoint 2\n";
  print STDERR "Finish with an empty line\n";
  my $count=1;
  while ( my $line = <> )
  {
    $line =~ /(\w{2}\s*\d{3,5}\s*\d{3,5})\s+(.*)/;
    if($1)
    {
      my $description = $2 || $count;
      push @waypoints, [$2, $1];
      $count++;
    }
    else
    {
      print STDERR "done\n";
      last;
    }
  }
  return @waypoints;
}




sub process_options
{
  my $opts_hashref = shift || die;
  GetOptions( "toFile=s"    => \$opts_hashref->{file},
              "toGPS=s"     => \$opts_hashref->{gps},
              "gpsDevice=s" => \$opts_hashref->{gps_device},
              "help"        => \&help
            ) || die "Command line options are incorrect";

  if( $opts_hashref->{file} && $opts_hashref->{gps} )
  {
    die "Cannot use both -toFile and -toGPS together\n";
  }
  if( ( $opts_hashref->{gps} || $opts_hashref->{gps_device} )
      && ( !$opts_hashref->{gps} || !$opts_hashref->{gps_device} ) 
    )
  {
    die "-toGPS and -gpsDevice must be set together\n";
  }
  #Test if we can find gpsbabel in the path, die if we can't
  if( $opts_hashref->{gps} )
  {
    if( system('which gpsbabel > /dev/null') )
    {
      die "could not find the path to gpsbabel\n";
    }
  }
}




sub help
{
  print "$0\n";
  print " -toFile <filename to write to>\n";
  print " -toGPS <gpsbabel gps type>\n";
  print " -gpsDevice <gpsbabel gps path, eg usb: or /dev/ttyUSB0\n";
  print "\n";
  print "This program is distributed under the GNU GPLv3 license, see http://www.gnu.org/licenses/ for more\n";
  exit(0);
}

