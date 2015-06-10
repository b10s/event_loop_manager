#!/usr/bin/env perl
 
use strict;
use AE;use EV;
use Guard;
use Time::HiRes;
use POSIX 'strftime';

use Data::Dumper;
 
sub ae_loop(&&$$);
 
my $parallel = $ARGV[0];
my $runat = AE::now;
srand(1);
 
sub debug {
	printf "[%06.2f : %s.%03d] %s\n",AE::now() - $runat,strftime("%Y-%m-%dT%H:%M:%S",localtime(time)),
	int((Time::HiRes::gettimeofday)[1]/1000),"@_";
}
 
{
	my $g1 = guard { debug "scope 1 freed" };
	my $g2 = guard { debug "scope 2 freed" };
	ae_loop
		sub { # called for every item from given array. $item contains reference to that item
			$g1;
			my ($item,$next) = @_;
			
			debug "processing $item";
			return debug "processed  $item" if $item eq "2"; # Extended feature. Keep watch for "lost" next
			
			my $t; $t = AE::timer rand(),0,sub {
				debug "processed  $item";
				undef $t; $next->();
			};
		},
		sub { # called when all items was processed (i.e. was called the latest next)
			$g2;
			debug "finished";
			AE::postpone {
				EV::unloop;
			};
		},
		100, # how many "parallels" to keep. 1 means make calls sequential. size of array means completely parallel
		[1 .. 1000];}
EV::loop;
debug("exiting");
sub ae_loop(&&$$) {
	my ($worker, $last, $parallel, $data ) = @_;
	my $counter = $parallel > @$data ? @$data : $parallel;
	my $next;
	my $chain = 0;	
	$next = sub {
		f();
		my $cb;
		if( my $item = shift @{$data} ) {
			$cb = $next;
			# save guard in closure, in case uncalled callback - guarded from lose callback
			my $guard_me = guard {  $next->();  };
			&$worker($item, sub {
				# callback is here, then we dont need guard
				$guard_me->cancel;
				$cb->();
			});
		} else {
			# we are last chain
			if( $chain ==1 ) {
				&$last;
			}
			$chain--;
		}
	};
	while ($counter--) {
		$chain++;
		$next->();
	}
}

sub f() {
        open my $f, "<:raw", "/proc/$$/stat";
        print join(",",(split(" ", scalar(<$f>)))[1,22,23]) , "\n";
}