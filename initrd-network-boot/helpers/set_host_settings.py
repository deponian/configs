#!/usr/bin/env python3

# :::::::::::::::::::::: Description ::::::::::::::::::::::::::::: #
# This script changes host-specific settings which cannot be
# set up in base image of the system like hostname and IP addresses
# It makes substitutions for templates that start with symbol "@"
# in several system files. Name of argument is the same as name of template.
# For example tempalte "@hostname" in file will be replaced by "hostname" command line argument.

import argparse
import shutil

parser = argparse.ArgumentParser(description="""
	This script changes host-specific settings
	which cannot be set up in base image of the system like hostname and IP addresses.
	It makes substitutions for templates that start with symbol "@" in several system files.
	Name of argument is the same as name of template. For example tempalte "@hostname" in file
	will be replaced by "hostname" command line argument.""")
parser.add_argument('ip_in_10_254', type=str, help='IP address in 10.254 QinQ VLAN')
parser.add_argument('ip_in_707', type=str, help='IP address in VLAN 707')
parser.add_argument('ip_in_2566', type=str, help='IP address in VLAN 2566')
parser.add_argument('hostname', type=str, help='Hostname')
parser.add_argument('-b', '--no-backups',
						action='store_false', dest='backup',
						help="""By default script creates backup copy for all files that it changes.
						If you don't want to make backups use this key.""")
args = parser.parse_args()

def replace_word_in_file(filename, old, new):
	# Read in the file
	try:
		with open(filename, 'r') as file:
			filedata = file.read()
	except IOError:
		print("Unable to open file")

	# Replace the target string
	filedata = filedata.replace(old, new)

	# Write the file out again
	try:
		with open(filename, 'w') as file:
			file.write(filedata)
	except IOError:
		print("Unable to open file")

	print("{0}: {1} was successfully replaced by {2}".format(filename, old, new))

def make_backup(filename):
	shutil.copy2(filename, filename + '.backup')
	print("{0}: backup has saved as {1}".format(filename, filename + '.backup'))

# Change IP and hostname in /etc/hosts
if args.backup:
	make_backup('/etc/hosts')
replace_word_in_file('/etc/hosts', '@ip_in_707', args.ip_in_707)
replace_word_in_file('/etc/hosts', '@hostname', args.hostname)

# Change hostname in /etc/hostname
if args.backup:
	make_backup('/etc/hostname')
replace_word_in_file('/etc/hostname', '@hostname', args.hostname)

# Change IP in /etc/nova/nova.conf
if args.backup:
	make_backup('/etc/nova/nova.conf')
replace_word_in_file('/etc/nova/nova.conf', '@ip_in_707', args.ip_in_707)

# Change IP addresses in /etc/network/interfaces
if args.backup:
	make_backup('/etc/network/interfaces')
replace_word_in_file('/etc/network/interfaces', '@ip_in_707', args.ip_in_707)
replace_word_in_file('/etc/network/interfaces', '@ip_in_2566', args.ip_in_2566)

# Change IP address in /usr/local/bin/create-vlan254in10
if args.backup:
	make_backup('/usr/local/bin/create-vlan254in10')
replace_word_in_file('/usr/local/bin/create-vlan254in10', '@ip_in_10_254', args.ip_in_10_254)

print("All changes were made successfully.")
