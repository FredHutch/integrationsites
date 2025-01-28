#!/usr/bin/python3

import sys

usage = "python extractGenesFromGFF.py inputMouseGenomicGFFFile outputMouseGenesGFFFile\n"
if len(sys.argv) < 3:
    print(usage)
    sys.exit(1)

inFile = sys.argv[1]
outFile = sys.argv[2]
gcount, rcount = 0, 0

with open(inFile, 'r') as in_file, open(outFile, 'w') as out_file:
    for line in in_file:
        if line.startswith('#'):
            continue
        fields = line.strip().split('\t')
        chromo, source, feature = fields[0], fields[1], fields[2]
        if feature == "region":
            out_file.write(line)
            rcount += 1
        elif feature == "gene" or feature == "pseudogene":
            out_file.write(line)
            gcount += 1

print(f"Total {rcount} regions, {gcount} genes/pseudogene.")
