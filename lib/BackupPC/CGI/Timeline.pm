#============================================================= -*-perl-*-
#
# BackupPC::CGI::Timeline package
#
# DESCRIPTION
#
#   This module implements the Timeline action for the CGI interface.
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

package BackupPC::CGI::Timeline;

use strict;
use BackupPC::CGI::Lib qw(:all);

# Default number of days to view (a number of days to look backwards).
my $URLParamDays = 3;
my $daysNumRE    = qr/^\d*(\.\d+)?$/;

&GetNumDays();

sub action {
    my ( $LatestBackupEnd, $EarliestBackupStart ) = &LatestBackupEnd();

    $Conf{CgiHeaders} .= <<EOF;

<script src="$Conf{CgiImageDirURL}/sorttable.js"></script>

<!-- Load the Timeline library -->
<script src="$Conf{CgiImageDirURL}/BackupPC_Timeline/timeline_2.3.1/timeline_ajax/simile-ajax-api.js?bundle=true" type="text/javascript"></script>
<script src="$Conf{CgiImageDirURL}/BackupPC_Timeline/timeline_2.3.1/timeline_js/timeline-api.js?bundle=true" type="text/javascript"></script>

<script src="$Conf{CgiImageDirURL}/BackupPC_Timeline/date.format.js" type="text/javascript"></script>
<script src="$Conf{CgiImageDirURL}/BackupPC_Timeline/setupFilterHighlightControls.js" type="text/javascript"></script>

<!-- Load the BackupPC configuration -->
<script>
    var Conf = new Object();
    Conf.CgiImageDirURL = "$Conf{CgiImageDirURL}";
    Conf.CgiDateFormatMMDD = $Conf{CgiDateFormatMMDD};
    Conf.MyURL = "$MyURL";
    var timeline_last_event = $LatestBackupEnd;
    var timeline_first_event = $EarliestBackupStart;
    var days = "$URLParamDays";
</script>

<link rel="stylesheet" href="$Conf{CgiImageDirURL}/BackupPC_Timeline/BackupPC_Timeline.css" type="text/css">
<script src="$Conf{CgiImageDirURL}/BackupPC_Timeline/BackupPC_Timeline.js" type="text/javascript"></script>

</head><body onload="document.getElementById('NavMenu').style.height=document.body.scrollHeight; onLoad();" onresize="onResize();">


<div id="navigation-container">
	<div id="logo-container">
		<a href="/"><img src="$Conf{CgiImageDirURL}/logo.gif"></a>
	</div>
EOF

    my $noBrowse = 0;
    my @adminLinks = (
        { link => "?action=status",        name => $Lang->{Status}},
        { link => "?action=summary",       name => $Lang->{PC_Summary}},
        { link => "?action=editConfig",    name => $Lang->{CfgEdit_Edit_Config},
                                           priv => 1},
        { link => "?action=editConfig&newMenu=hosts",
                                           name => $Lang->{CfgEdit_Edit_Hosts},
                                           priv => 1},
        { link => "?action=adminOpts",     name => $Lang->{Admin_Options},
                                           priv => 1},
        { link => "?action=view&type=LOG", name => $Lang->{LOG_file},
                                           priv => 1},
        { link => "?action=LOGlist",       name => $Lang->{Old_LOGs},
                                           priv => 1},
        { link => "?action=emailSummary",  name => $Lang->{Email_summary},
                                           priv => 1},
        { link => "?action=queue",         name => $Lang->{Current_queues},
                                           priv => 1},
        @{$Conf{CgiNavBarLinks} || []},
    );
    my $host = $In{host};


        $Conf{CgiHeaders} .= <<EOF;
<div class="NavMenu" id="NavMenu">
EOF
    my $hostSelectbox = "<option value=\"#\">$Lang->{Select_a_host}</option>";
    my @hosts = GetUserHosts($Conf{CgiNavBarAdminAllHosts});
        $Conf{CgiHeaders} .= "<h2 class='NavTitle'>$Lang->{Hosts}</h2>";
    if ( defined($Hosts) && %$Hosts > 0 && @hosts ) {
        foreach my $host ( @hosts ) {
	    NavLink("?host=${EscURI($host)}", $host)
		    if ( @hosts < $Conf{CgiNavBarAdminAllHosts} );
	    my $sel = " selected" if ( $host eq $In{host} );
	    $hostSelectbox .= "<option value=\"?host=${EscURI($host)}\"$sel>"
			    . "$host</option>";
        }
    }
    if ( @hosts >= $Conf{CgiNavBarAdminAllHosts} ) {
        $Conf{CgiHeaders} .= <<EOF;
<select onChange="document.location=this.value">
$hostSelectbox
</select>
EOF
    }
    if ( $Conf{CgiSearchBoxEnable} ) {
        $Conf{CgiHeaders} .= <<EOF;
<form action="$MyURL" method="get">
    <input type="text" name="host" size="14" maxlength="64">
    <input type="hidden" name="action" value="hostInfo"><input type="submit" value="$Lang->{Go}" name="ignore">
    </form>
EOF
    }
    $Conf{CgiHeaders} .= "<h2 class='NavTitle'>$Lang->{NavSectionTitle_}</h2>";
    foreach my $l ( @adminLinks ) {
        if ( $PrivAdmin || !$l->{priv} ) {
            my $txt = $l->{lname} ne "" ? $Lang->{$l->{lname}} : $l->{name};
            $Conf{CgiHeaders} .= "<a href=\"$l->{link}\">$txt</a>";
        }
    }

    $Conf{CgiHeaders} .= <<EOF;
</div>
</div> <!-- end #navigation-container -->


<!--[if False]> Skip header lines
EOF

    Header( "BackupPC Timeline", &Content() );
    Trailer();
}

sub LatestBackupEnd {
    my $latest   = 0;
    my $earliest = time();

    # Calculate cutoff threshold for oldest end timestamp to keep.
    my $threshold = time() - ( $URLParamDays * 86400 );

    for my $host ( GetUserHosts(1) ) {

        next if ( $bpc->{Conf}{XferMethod} eq "archive" );

        # [-1] in the line below implies most recent backup for each host.
        for ( ( $bpc->BackupInfoRead($host) )[-1] ) {
            next if ( $_->{endTime} < $latest );
            $latest = $_->{endTime};
        }

        for ( $bpc->BackupInfoRead($host) ) {

            # Filter out anything that ended before $threshold.
            next if ( $_->{endTime} < $threshold );
            next if ( $_->{startTime} > $earliest );
            $earliest = $_->{startTime};
        }

    }
    return ( $latest, $earliest );
}

sub Content {
    my $content = <<EOF;

<![endif]-->

    <div class="h1">BackupPC Timeline</div>
    <br>
    <noscript>
        <p><h2>This page uses Javascript to show you a Timeline.<br>
        Please enable Javascript in your browser to see the full page.</h2></p>
    </noscript>

    <div id="tl"></div>

    <!-- Moving controls -->
    <div id="movcontrols" align="center" style="width:100%;">
        <div align="left" style="width:20%; float:left">
            <input type="button"
                value="<<"
                onClick="setTimelineFirstEvent();">
        </div>
        <div align="right" style="width:20%; float:right">
            <input type="button"
                value=">>"
                onClick="setTimelineLastEvent();">
        </div>
        <div align="center" style="width:59%;">
            <form action="$MyURL" method="get">
Show number of days
                <input type="text" name="days" value="$URLParamDays" size="5" maxlength="8" pattern="$daysNumRE" required>
                <input type="hidden" name="action" value="timeline"><input type="submit" value="$Lang->{Go}" name="ignore">
            </form>
        </div>
    </div>

    <div id="legend">
        <div>
            <li><hr style ="background-color:blue; color:blue;" /></li>
            <li>Full</li>
        </div>
        <div>
            <li><hr style ="background-color:green; color:green;" /></li>
            <li>Incremental</li>
        </div>
        <div>
            <li><hr style ="background-color:maroon; color:maroon;" /></li>
            <li>Partial</li>
        </div>
        <div>
            <li><hr style ="background-color:red; color:red;" /></li>
            <li>With errors</li>
        </div>
    </div>

    <p>To move the Timeline: use the mouse scroll wheel, the arrow keys or grab and drag the Timeline.
        Click any entry for backup info in a popup bubble.</p>

    <div id="controls"></div>

    <p>If an event matches the text in any of the boxes, then the event passes the filter.
        This is "ORing" together the input boxes.</p>
</div>
EOF

    return $content;
}

sub GetNumDays {
    if ( defined( $In{days} )
        && ( $In{days} =~ $daysNumRE ) )
    {
        $URLParamDays = $In{days};
    }
}

1;
