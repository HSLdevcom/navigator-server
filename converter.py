import sys
import csv

dest_csv = csv.reader(open('dest.skv', 'r'), delimiter=';')
journey_csv = csv.reader(open('journey.skv', 'r'), delimiter=';')
pointlst_csv = csv.reader(open('pointlst.skv', 'r'), delimiter=';')

dest = {}
dep_times = {}

def jore_code(line):
  if line in ('506', '512K', '550', '550B', '552', '554', '554K'):
    return '2'+line
  elif line in ('415', '451', '519', '519A', '520', '615', '615T', '615TK', '615V', '615VK', '620'):
    return '4'+line
  elif line in ('61', '61V'):
    return '40'+line
  elif line in ('1', '1A', '2', '2X', '3', '3X', '4', '4T', '5', '6', '6T', '6X', '7A', '7B', '8', '9', '9X'):
    return '100'+line
  else:
    return '10'+line

for line in dest_csv:
  dest[line[3]] = jore_code(line[4].split(' ')[0])

for line in pointlst_csv:
  if line[6] == '1':
    dep_times[line[3]+';'+line[4]+';'+line[5]] = line[14][:4]

for line in journey_csv:
  if line[11] in dest:
    print line[3]+'_'+line[4]+'_'+line[5]+';'+line[6]+';'+dest[line[11]]+';'+dep_times[line[3]+';'+line[4]+';'+line[5]]
  else:
    print >>sys.stderr, "pattern %s not found" % line[11]
