package t::SimpleTree;
use List::Util qw/all/;
use overload
  '==' => sub { $_[0]->hash eq $_[1]->hash },
  '!=' => sub { $_[0]->hash ne $_[1]->hash };
use strict;
use warnings;

my $distop = qr{[*+]|and|or}i;
my $binop = qr{[/%-]|[><!]?=|[<>]|xor};
my $commop = qr{[*+]|and|x?or}i;
my $norm = { 'is not null' => 'is_not_null',
	     'is null' => 'is_null' };
sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
}

sub parse {
  # lispify
  my ($self, $s) = @_;
  # normalize
  $s = lc $s;
  while (my ($from,$to) = each %$norm) {
    $s =~ s/$from/$to/g;
  }
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
  $self->{tree} or die "No tree!";
  my $do;
  $do = sub {
    my $a = shift;
    if (ref $a eq 'ARRAY') {
      if (!scalar @$a) {
	return '.';
      }
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

1;

=head1 NAME

t::SimpleTree : simple syntax tree for comparing simple expressions

=head1 SYNOPSIS

 use t::SimpleTree;
 my $p = t::SimpleTree->new;
 my $q = t::SimpleTree->new();
 my $expr1 = 'a + b + exp(c) and ( ( m <> ln(2) ) or ( max(l,m,q) ) )';
 my $expr2 = '(((a + b + exp(c) and ( (( m <> ln(2)) ) or ( max(l,m,q) ) ))))';
 $p->parse($expr1);
 $q->parse($expr2);
 if ($p == $q) {
  print "Equivalent";
 }

=head1 METHODS

=over

=item new()

=item parse()

Parse an expression and store the tree in the object. Tree is also returned
as a lisp-like nested array structure.

=item hash()

Create a string that captures the structure but sorts arguments of 
commutative operations. The hashes of two trees can be string-compared
to infer equivalence of the underlying expressions.

=item $t == $s, $t != $s

== and != are overloaded to compare the hashes of two trees.

=back

=cut
