#!/usr/bin/env python
import csv
import cPickle
from zipfile import ZipFile

import gdal
from django.contrib.gis.geos import GEOSGeometry, LineString, Point

WGS84_SRID=4326
TARGET_SRID=900913

class GTFS(object):
    def __init__(self, city, fname):
        self.city = city
        self.zipf = ZipFile(fname, 'r')
    def parse_shapes(self):
        pickle_fname = "%s-shapes.pkl" % self.city
        print "Importing shapes"
        try:
            pfile = open(pickle_fname, 'rb')
        except Exception as e:
            pfile = None
        if pfile:
            print "Loading from pickle"
            self.shapes = cPickle.load(pfile)
            pfile.close()
            print "Loaded"
            return

        f = self.zipf.open('shapes.txt', 'r')
        self.shapes = {}
        f.readline()
        for idx, line in enumerate(f):
            (shape_id, lat, lon, seq) = line.strip().split(',')
            arr = shape_id.split('_')
            shape_id = '_'.join((arr[0], arr[2]))
            if shape_id in self.shapes:
                d = self.shapes[shape_id]
            else:
                d = {'points': []}
                self.shapes[shape_id] = d
            d['points'].insert(int(seq) - 1, (float(lat), float(lon)))
        print "Imported %d points for %d shapes" % (idx, len(self.shapes))
        pfile = open(pickle_fname, 'wb')
        cPickle.dump(self.shapes, pfile, -1)

    def parse_stops(self):
        pickle_fname = "%s-stops.pkl" % self.city
        print "Importing shapes"
        try:
            pfile = open(pickle_fname, 'rb')
        except Exception as e:
            pfile = None
        if pfile:
            print "Loading from pickle"
            self.stops = cPickle.load(pfile)
            pfile.close()
            print "Loaded"
            return

        f = self.zipf.open('stops.txt', 'r')
        self.stops = {}
        reader = csv.reader(f)
        reader.next()
        for idx, row in enumerate(reader):
            (stop_id, stop_code, stop_name, stop_desc, stop_lat, stop_lon, zone_id, stop_url, location_type, parent_station) = row
            if stop_id not in self.stops:
                self.stops[stop_id] = {}
            d = self.stops[stop_id]
            d['location'] = (stop_lat, stop_lon)
            d['name'] = stop_name
        print "Imported %d stops" % len(self.stops)
        pfile = open(pickle_fname, 'wb')
        cPickle.dump(self.stops, pfile, -1)

    def generate_lines(self):
        for shape_id in self.shapes:
            d = self.shapes[shape_id]
            pnts = [(x[1], x[0]) for x in d['points']]
            line = LineString(pnts, srid=WGS84_SRID)
            d['line'] = shape_id
        print "GEOS Geometries generated"

class HSLLiveFeed(object):
    COL_NAMES = (
        "id", "name", "type", "ip", "lat", "lng", "speed", "bearing",
        "acceleration", "gps_time_difference", "unix_epoch_gps_time", "low_floor", "route", "direction",
        "departure", "departure_time", "departure_starts_in", "distance_from_start", "snapped_lat", "snapped_lng",
        "snapped_bearing", "next_stop_index", "on_stop", "difference_from_timetable"
    )

    def __init__(self, fname, gtfs):
        self.gtfs = gtfs
        self.feedf = open(fname, 'r')
        self.routes = {}
        self.pickle_fname = "hsl-feed.pkl"
    def add_sample(self, info):
        route_id = "%s_%s" % (info['route'], info['direction'])
        if route_id not in self.routes:
            self.routes[route_id] = {}
        route = self.routes[route_id]
        trip_id = info['departure_time']
        if not trip_id in route:
            route[trip_id] = {'points': []}
        trip = route[trip_id]

        ts = int(info['unix_epoch_gps_time'])
        # If the sample is there already, don't add it.
        if len(trip['points']):
            last_sample = trip['points'][-1]
            if last_sample[2] == ts:
                return
            # Also skip samples that are sent off-sequence.
            if last_sample[2] > ts:
                return
            # ... or the ones that are skip too much.
            if ts - last_sample[2] > 5*60*1000:
                return
        trip['points'].append((float(info['lat']), float(info['lng']), ts))

    def parse_feed(self):
        try:
            pfile = open(self.pickle_fname, 'rb')
        except Exception as e:
            pfile = None
        if pfile:
            print "Loading feed from pickle"
            self.routes = cPickle.load(pfile)
            pfile.close()
            print "Loaded"
            return

        for idx, line in enumerate(self.feedf):
            line = line.strip().split(';')
            if len(line) < 3:
                continue
            d = {}
            for col_idx, c in enumerate(self.COL_NAMES):
                d[c] = line[col_idx]
            if d['lat'] == '0' or d['lng'] == '0':
                continue
            if d['unix_epoch_gps_time'][0] == '-':
                continue
            if not d['route']:
                continue
            if idx == 1000000:
                break
            self.add_sample(d)
        self.save_feed()

    def save_feed(self):
        f = open(self.pickle_fname, 'wb')
        cPickle.dump(self.routes, f, -1)

    def print_trip(self, route_id, trip_id):
        route = self.routes[route_id]
        trip = route[trip_id]
        last_ts = 0
        for p in trip['points']:
            print "%d, %d" % (p[2], p[2] - last_ts)
            last_ts = p[2]

    def analyse_route(self, route_id):
        route = self.routes[route_id]
        shape = self.gtfs.shapes[route_id]
        pnts = [(x[1], x[0]) for x in shape['points']]
        line = LineString(pnts, srid=WGS84_SRID)
        print line
        line.transform(TARGET_SRID)
        #for trip_id in route.keys():
        print line.length
        for trip_id in ('21032013201700',):
            print trip_id
            pnts = [(s[1], s[0]) for s in route[trip_id]['points']]
            sample_line = LineString(pnts, srid=WGS84_SRID)
            sample_line.transform(TARGET_SRID)
            sample_line = sample_line.simplify(4)
            sample_line.transform(WGS84_SRID)

            for s in route[trip_id]['points']:
                pnt = Point(s[1], s[0], srid=WGS84_SRID)
                pnt.transform(TARGET_SRID)
                dist = line.project(pnt)
                print "%s %f" % (s, dist)
        print route.keys()

hel = GTFS('helsinki', 'hel/google_transit.zip')

hel.parse_shapes()
hel.parse_stops()
exit(1)

feed = HSLLiveFeed('hsllive.txt', hel)
feed.parse_feed()

#feed.print_trip('1003T_1', '21032013203400')
#exit(1)

feed.analyse_route('1004_1')
exit(1)

for route_id in feed.routes:
    route = feed.routes[route_id]
    print route_id
    for trip_id in route:
        trip = route[trip_id]
        last_ts = 0
        max_diff = 0
        for p in trip['points']:
            ts = p[2]
            if last_ts:
                assert ts > last_ts
                diff = (ts - last_ts) / 1000
                if diff > max_diff:
                    max_diff = diff
            last_ts = ts
        print "\t%s: %d" % (trip_id, max_diff)

