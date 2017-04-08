package t::SimpleTree;
use List::Util qw/all/;
use strict;
use warnings;

my $distop = qr{[*+]|and|or}i;
my $binop = qr{[/%-]|[><!]?=|[<>]|xor};
my $commop = qr{[*+]|and|x?or}i;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
}

sub parse {
  # lispify
  my ($self, $s) = @_;
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
	# descend
	push @$x, $do->([]);
      }
      elsif ($t eq ')') {
	# ascend
	my $op = $$x[0];
	return $x;
      }
      elsif ($t =~ /^([a-z]+)\(/i) {
	# function
	my $a = [lc $1];
	push @$x, $do->([lc $1]);
      }
      elsif ($t =~ /$binop|$distop/) {
	if ($$x[0] and
	      $$x[0] !~ /$binop|$distop/) { # operands only so far
	  # add operator
	  unshift @$x, $t;
	}
	elsif ($$x[0] and
		 $$x[0] =~ /$distop/ and
		 $$x[0] eq $t) {
	  # same operator and distributable
	  # push the next operand into same list
	  1; # ignore
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

  # remove redundant ()
  my $simp;
  $simp = sub {
    my $a = shift;
    if (ref $a eq 'ARRAY') {
      if (@$a == 1 and ref $$a[0] eq 'ARRAY') {
	return $simp->($$a[0]);
      }
      return [ map { $simp->($_) } @$a ];
    }
    else {
      return $a;
    }
  };

  return $self->{tree} = $simp->( $do->([]) );
}

sub hash {
  my $self = shift;
  $self->{hash} && return $self->{hash};
  $self->{tree} or die "No tree!";
  my $do;
  $do = sub {
    my $a = shift;
    if (ref $a eq 'ARRAY') {
      if ( all { ref eq '' } @$a ) {
	return $$a[0] =~ /$commop/ ?
	  join('',$$a[0],sort @{$a}[1..$#$a]) :
	  join('',@$a);
      }
      else {
	return $$a[0] =~ /$commop/ ?
	  join('',$$a[0],sort map { $do->($_) } @{$a}[1..$#$a]) :
	  join('',$$a[0], map { $do->($_) } @{$a}[1..$#$a]) ;
      }
    }
    else {
      return $a;
    }
  };

  $self->{hash} = $do->($self->{tree});
}
