#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;

sub usage()
{
	print STDERR << "EOF";
Diff two files regardless of order of lines - uses perl hash.

-h	: this message
-a	: first input file
-b	: second input file

usage: $0 -a file1.txt -b file2.txt
EOF
	exit;
}

my %args;
getopts('ha:b:', \%args);

if ($args{h}){
	usage;
}

my @lista;
open (LISTA, "$args{a}") or die $!;
while (<LISTA>) {
	chomp;
	push(@lista, $_);
}
close(LISTA);
my %lista = map { $_ => 1 } @lista;

my @listb;
open (LISTB, "$args{b}") or die $!;
while (<LISTB>) {
	chomp;
	push(@listb, $_);
}
close(LISTB);
my %listb = map { $_ => 1 } @listb;

#print Dumper(\%lista);
for (keys %lista) {
	unless (exists $listb{$_}) {
		print "$_: not found in listb\n";
		next;
	}
	if ($lista{$_} eq $listb{$_}) {
		print "$_: values are equal\n";
	}
	else {
		print "$_: values are not equal\n";
	}
}

for (keys %listb) {
	unless (exists $lista{$_}) {
		print "$_: not found in lista\n";
	}
}
