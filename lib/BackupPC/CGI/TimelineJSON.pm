#============================================================= -*-perl-*-
#
# BackupPC::CGI::TimelineJSON package
#
# DESCRIPTION
#
#   This module implements the TimelineJSON action for the CGI interface.
#
# AUTHOR
#   Alexander Moisseev <moiseev@mezonplus.ru>
#
# COPYRIGHT
#   Copyright (C) 2014  Alexander Moisseev
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#========================================================================
#
# Module version 0.0.2, released 19 Feb 2014.
#
#========================================================================

package BackupPC::CGI::TimelineJSON;

use strict;
use BackupPC::CGI::Lib qw(:all);

# Default number of days to view (a number of days to look backwards).
my $URLParamDays = 3;
my $daysNumRE    = qr/^\d*(\.\d+)?$/;

&GetNumDays();

sub action {

    # Calculate cutoff threshold for oldest end timestamp to keep.
    my $threshold = time() - ( $URLParamDays * 86400 );

    # JSON data header
    print <<EOF;
Content-Type: application/json

{

'events': [

EOF

    my ($untaintedMyURL) = $MyURL =~ /^([-~.\/\w]+)$/;
    my $notFirstEvent = 0;

    for my $host ( GetUserHosts(1) ) {
        next if ( $bpc->{Conf}{XferMethod} eq "archive" );
        for ( $bpc->BackupInfoRead($host) ) {

            # Filter out anything that ended before $threshold
            next if ( $_->{endTime} < $threshold );

            print ",\n\n"
              if $notFirstEvent++;

            printf "{'start': %s,\n",  Timeconv( $_->{startTime} );
            printf "'end': %s,\n",     Timeconv( $_->{endTime} );
            printf "'title': '%s',\n", $host;
            printf "'link': '" . $untaintedMyURL . "?host=%s',\n", $host;
            printf "'description': 'Backup #: %d', \n", $_->{num},;
            printf "'caption': 'Backup#: %d',\n",       $_->{num};

            # Colorise event tapes:
            if ( $_->{type} eq "partial" ) {
                print "'color': 'maroon'";
            }
            elsif ($_->{xferErrs}
                || $_->{xferBadFile}
                || $_->{xferBadShare}
                || $_->{tarErrs} )
            {
                print "'color': 'red'";
            }
            elsif ( $_->{type} eq "incr" ) {
                print "'color': 'green'";
            }
            elsif ( $_->{type} eq "full" ) {
                print "'color': 'blue'";
            }
            else {
                print "'color': 'fuchsia'";
            }

            print "}";
        }
    }

    # Close JSON data
    print <<EOF;


]
}

EOF

}

sub Timeconv {
#
# Convert epoch timestamps into the JS date format
#
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime( shift(@_) );
    return sprintf(
        "new Date(Date.UTC(%04i,%02i,%02i,%02i,%02i,%02i))",
        $year + 1900, $mon, $mday, $hour, $min, $sec
    );
}

sub GetNumDays {
    if ( defined( $In{days} )
        && ( $In{days} =~ $daysNumRE ) )
    {
        $URLParamDays = $In{days};
    }
}

1;
