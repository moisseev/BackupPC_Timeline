/*
 *   BackupPC_Timeline.js 0.0.2, 2014-02-19
 *   Copyright (C) 2014  Alexander Moisseev <moiseev@mezonplus.ru>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

"use strict";

var tl, now;

// Disable history dummy page http requests
SimileAjax.History.enabled = false;

// Replace GMT timestamps in bubbles with BackupPC CGI display format.
Timeline.GregorianDateLabeller.prototype.labelPrecise = function(date) {
    var date, mask;

    // Remove browser time zone offset.
    date = SimileAjax.DateTime.removeTimeZoneOffset(
        date,
        new Date().getTimezoneOffset() / 60 );

    if ( Conf.CgiDateFormatMMDD === 2 ) {
        mask = "yyyy-mm-dd";
    } else {
        if ( Conf.CgiDateFormatMMDD ) {
            mask = "m/d";
        } else {
            mask = "d/m";
        }
        // Add the year if the time is more than 330 days ago
        // 28512000000 = 330 * 24 * 3600 * 1000
        if ( now - date > 28512000000 ) {
            mask = mask + "/yy";
        }
    }
    mask = mask + " HH:MM";
    return date.format(mask);
};

function onLoad() {
    now = SimileAjax.DateTime.removeTimeZoneOffset(
        new Date(),
        -SimileAjax.DateTime.timezoneOffset / 60 );
    var tl_el = document.getElementById("tl");
    var eventSource1 = new Timeline.DefaultEventSource();
    var theme1 = Timeline.ClassicTheme.create();
    theme1.autoWidth = true; // Set the Timeline's "width" automatically.
                             // Set autoWidth on the Timeline's first band's theme,
                             // will affect all bands.
    theme1.timeline_start = new Date(now - days*24*3600*1000);
    theme1.timeline_stop  = now;
    theme1.event.bubble.width = 150;

    var bandInfos = [
        Timeline.createBandInfo({
            width:          45, // set to a minimum, autoWidth will then adjust
            intervalUnit:   Timeline.DateTime.HOUR,
            intervalPixels: 180,
            eventSource:    eventSource1,
            theme:          theme1
        }),
        Timeline.createBandInfo({
            overview:       true,
            width:          45, // set to a minimum, autoWidth will then adjust
            intervalUnit:   Timeline.DateTime.DAY,
            intervalPixels: 240,
            eventSource:    eventSource1,
            theme:          theme1
        }),
        Timeline.createBandInfo({
            overview:       true,
            width:          45, // set to a minimum, autoWidth will then adjust
            intervalUnit:   Timeline.DateTime.MONTH,
            intervalPixels: 150,
            eventSource:    eventSource1,
            theme:          theme1
        })
    ];

    bandInfos[1].syncWith = 0;
    bandInfos[1].highlight = true;
    bandInfos[2].syncWith = 0;
    bandInfos[2].highlight = true;

    // For each of the bands, add a decorator at the start and end
    // of the Timeline. The decorators have to extend quite a way into
    // the past and future since those times can be visible on the
    // low resolution band (the third band)
    for (var i = 0; i < bandInfos.length; i++) {
        bandInfos[i].decorators = [
            new Timeline.SpanHighlightDecorator({
                startDate:  "1", // The year 1 Common Era
                endDate:    theme1.timeline_start,
                cssClass:   "decorator",
                opacity:    20,
                theme:      theme1
            }),
            new Timeline.SpanHighlightDecorator({
                startDate:  theme1.timeline_stop,
                endDate:    new Date(Date.UTC(8000, 0, 0)),
                cssClass:   "decorator",
                opacity:    20,
                theme:      theme1
            })
        ];
    }

    // Create the Timeline.
    tl = Timeline.create(tl_el, bandInfos, Timeline.HORIZONTAL);

    // Stop browser caching of data during testing by appending time.
    tl.loadJSON(Conf.MyURL + "?action=" + "timelineJSON&" + "days=" + days + "&" + (new Date().getTime()), function(json, url) {
        eventSource1.loadJSON(json, url);
        // Also (now that all events have been loaded), automatically re-size
        tl.finishedEventLoading(); // Automatically set new size of the div

        setTimelineLastEvent();    // Position timeline bands to last event end
    });

    setupFilterHighlightControls(document.getElementById("controls"), tl, [0,1], theme1);

    tl.layout(); // display the Timeline
}

var resizeTimerID = null;
function onResize() {
    if (resizeTimerID == null) {
        resizeTimerID = window.setTimeout(function() {
            resizeTimerID = null;
            tl.layout();
            setTimelineLastEvent();
        }, 0);
    }
}

// Add 90 seconds to highlight line ending
var timeline_first_event = SimileAjax.DateTime.removeTimeZoneOffset(
    new Date(timeline_first_event * 1000 - 90000),
    -SimileAjax.DateTime.timezoneOffset / 60 );
var timeline_last_event = SimileAjax.DateTime.removeTimeZoneOffset(
    new Date(timeline_last_event * 1000 + 90000),
    -SimileAjax.DateTime.timezoneOffset / 60 );

function setTimelineFirstEvent() {
    tl.getBand(0).setMinVisibleDate(timeline_first_event);
}

function setTimelineLastEvent() {
    tl.getBand(0).setMaxVisibleDate(timeline_last_event);
}
