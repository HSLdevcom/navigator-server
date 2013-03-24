#!/usr/bin/env python

import csv

trips_file_lines = file("trips.txt").readlines()
stop_times_lines = file("stop_times.txt").readlines()
stopfile = file("stops.txt").readlines()


route_id = "GMN:   1:C:" # XXX hardcoded route id

print route_id

def route_to_trips(route_id):
    trips = []
    for line in trips_file_lines:
        if not line.startswith(route_id+","):
            continue
        trips += [line.split(",", 4)[2]]

#    for trip in trips:
#        print trip

    return trips

def trip_to_stops(trip_id):

    stops = []
    for line in stop_times_lines:
        if not line.startswith(trip_id+","):
            continue
        stops += [line.split(",")[3]]

    return stops

def stop_id_to_stop(stop_id):

    reader = csv.reader(stopfile)
    reader.next()
    for idx, row in enumerate(reader):
        if row[0] == stop_id:
            return row

trip_ids = route_to_trips(route_id)[0:1] # XXX consider only first trip

for trip_id in trip_ids:
    stop_ids = trip_to_stops(trip_id) 
    print len(stop_ids)

stops = [stop_id_to_stop(stop_id) for stop_id in stop_ids]


output = file("line_stops.txt", "wt")
for row in stops:
# hsl:   (stop_id, stop_code, stop_name, stop_desc, stop_lat, stop_lon, zone_id, stop_url, location_type, parent_station) = row
    (stop_id, stop_code, stop_name, stop_lat, stop_lon, stop_url) = row
    print >>output, ",".join([stop_id, stop_lat, stop_lon])

output = file("line_stops.wkt", "wt")
print >>output, "LINESTRING(",
print >>output, ", ".join(stop_lon + " " + stop_lat for (stop_id, stop_code, stop_name, stop_lat, stop_lon, stop_url) in stops),
print >>output, ")"

