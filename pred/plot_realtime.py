#!/usr/bin/env python

import json

for line in file("mcr/1.txt").readlines():
#    print line
    if not line.strip():
        continue
    timestamp, datastring = line.split(" ", 1)
    if not datastring.strip():
        continue
    data = json.loads(datastring)
    for item in data:
        if item["Registration"] != "28020":
            continue
        print " ".join(str(item[key]) for key in "Longitude Latitude".split())+",",
#    if data['Id'] != "16":
#        continue
    
