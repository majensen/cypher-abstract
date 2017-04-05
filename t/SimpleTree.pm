package t::SimpleTree;
use strict;
use warnings;

my $distop = qr{[*+]|and|or}i;
my $binop = qr{[/%-]|[><!]?=|[<>]|xor};

sub new {
  my $class = shift;
  my $self = {};
  return $self, $class;
}

sub parse {
  my ($self, $s) = @_;
  $DB::single=1;
  my @tok = split /([a-z]*\(|\)|\s+)/, $s;
  @tok = grep { !/^\s*$/ } @tok;
  my $do;
  $do = sub {
    my ($x) = @_;
    while (my $t = shift @tok) {
      if (!defined $t) {
	return $x;
      }
      elsif ($t eq '(') {
	push @$x, $do->([]);
      }
      elsif ($t eq ')') {
	my $op = $$x[0];
	return $x;
      }
      elsif ($t =~ /^([a-z]+)\(/i) { # fn
	my $a = [lc $1];
	push @$x, $do->([lc $1]);
      }
      elsif ($t =~ /$binop|$distop/) {
	if ($$x[0] and
	      $$x[0] !~ /$binop|$distop/) {
	  unshift @$x, $t;
	}
	else {
	  $x = [$t, $x];
	}
      }
      else {
	# normalize token
	push @$x, lc $t;
      }
    }
    return $x;
  };

  return $do->([]);
}
