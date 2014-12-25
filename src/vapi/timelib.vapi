/* Copyright 2014 Nicolas Laplante
 *
 * This file is part of envelope.
 *
 * envelope is free software: you can redistribute it
 * and/or modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * envelope is distributed in the hope that it will be
 * useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with envelope. If not, see http://www.gnu.org/licenses/.
 */

/**
 * Timelib namespace
 *
 * Timelib is a timezone and date/time library that can calculate local time,
 * convert between timezones and parse textual descriptions of date/time
 * information.
 */
[CCode (cheader_filename = "timelib.h")]
namespace Timelib {

    /**
     *
     */
    [CCode (cname = "timelib_sll", has_type_id = false)]
    public struct sll : long {}

    /**
     *
     */
    [CCode (cname = "timelib_ull", has_type_id = false)]
    public struct ull : ulong {}

    /**
     *
     */
    [CCode (cname = "struct ttinfo", has_type_id = true)]
    [SimpleType]
    public struct ttinfo {
        public int32 offset;
        public int   isdst;
        public uint  abbr_idx;
        public uint  isstdcnt;
        public uint  isgmtcnt;
    }

    /**
     *
     */
    [CCode (cname = "struct tlinfo", has_type_id = true)]
    [SimpleType]
    public struct tlinfo {
        public int32 trans;
        public int32 offset;
    }

    /**
     *
     */
    [CCode (cname = "struct tlocinfo", has_type_id = true)]
    [SimpleType]
    public struct tlocinfo {
        public char    country_code[3];
        public double  latitude;
        public double  longitude;
        public string  comments;
    }

    /**
     *
     */
    [CCode (cname = "struct timelib_tzinfo", has_type_id = true)]
    [SimpleType]
    public struct tzinfo {
        public string   name;
        public uint32   ttisgmtcnt;
        public uint32   ttisstdcnt;
        public uint32   leapcnt;
        public uint32   timecnt;
        public uint32   typecnt;
        public int32    *trans;
        public uint32   charcnt;
        public string   trans_idx;
        public ttinfo   type;
        public string   timezone_abbr;
        public tlinfo   leap_times;
        public char     bc;
        public tlocinfo location;
    }

    /**
     *
     */
    [CCode (cname = "struct timelib_special", has_type_id = true)]
    [SimpleType]
    public struct special {
        public uint type;
        public sll  amount;
    }

    /**
     *
     */
    [CCode (cname = "struct timelib_rel_time", has_type_id = true)]
    [SimpleType]
    public struct rel_time {
        public sll      y;
        public sll      m;
        public sll      d;
        public sll      h;
        public sll      i;
        public sll      s;
        public int      weekday; /* Stores the day in 'next monday' */
        public int      weekday_behavior; /* 0: the current day should *not* be counted when advancing forwards; 1: the current day *should* be counted */
        public int      first_last_day_of;
        public int      invert; /* Whether the difference should be inverted */
        public sll      days; /* Contains the number of *days*, instead of Y-M-D differences */
        public special  special;
        public uint     have_weekday_relative, have_special_relative;
    }

    /**
     *
     */
    [CCode (cname = "struct timelib_time_offset", has_type_id = true)]
    [SimpleType]
    public struct time_offset {
        public int32    offset;
        public uint     leap_secs;
        public uint     is_dst;
        public string   abbr;
        public sll      transistion_time;
    }

    /**
     *
     */
    [CCode (cname = "struct timelib_time", has_type_id = true)]
    [SimpleType]
    public struct time {
        public sll      y;
        public sll      m;
        public sll      d;     /* Year, Month, Day */
        public sll      h;
        public sll      i;
        public sll      s;     /* Hour, mInute, Second */
        public double   f;           /* Fraction */
        public int      z;           /* GMT offset in minutes */
        public string   tz_abbr;     /* Timezone abbreviation (display only) */
        public tzinfo   tz_info;     /* Timezone structure */
        public int      dst;         /* Flag if we were parsing a DST zone */
        public rel_time relative;
        public sll      sse;         /* Seconds since epoch */
        public uint     have_time;
        public uint     have_date;
        public uint     have_zone;
        public uint     have_relative;
        public uint     have_weeknr_day;
        public uint     sse_uptodate; /* !0 if the sse member is up to date with the date/time members */
        public uint     tim_uptodate; /* !0 if the date/time members are up to date with the sse member */
        public uint     is_localtime; /*  1 if the current struct represents localtime, 0 if it is in GMT */
        public uint     zone_type;    /*  1 time offset, 3 TimeZone identifier, 2 TimeZone abbreviation */
    }

    /**
     *
     */
    [CCode (cname = "struct timelib_error_message", has_type_id = true)]
    [SimpleType]
    public struct error_message {
        public int    position;
        public char   character;
        public string message;
    }

    /**
     *
     */
    [CCode (cname = "struct timelib_error_container", has_type_id = true)]
    [SimpleType]
    public struct error_container {
        int                           warning_count;
        struct timelib_error_message *warning_messages;
        int                           error_count;
        struct timelib_error_message *error_messages;
    }

    /**
     *
     */
    [CCode (cname = "timelib_day_of_week")]
    public sll day_of_week (sll year, sll month, sll day);

    /**
     *
     */
    [CCode (cname = "timelib_iso_day_of_week")]
    public sll iso_day_of_week (sll year, sll month, sll day);

    /**
     *
     */
    [CCode (cname = "timelib_day_of_year")]
    public sll day_of_year (sll year, sll month, sll day);

    /**
     *
     */
    [CCode (cname = "timelib_daynr_from_weeknr")]
    public sll daynr_from_weeknr (sll year, sll week, sll day);

    /**
     *
     */
    [CCode (cname = "timelib_days_in_month")]
    public sll days_in_month (sll year, sll month);

    /**
     *
     */
    [CCode (cname = "timelib_isoweek_from_date")]
    public void isoweek_from_date (sll year, sll month, sll day, out sll iso_week, out sll iso_year);
}
