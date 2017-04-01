package Neo4j::Cypher::Abstract::Peeler;
use Carp;
use List::Util qw(all none);
use strict;
use warnings;

# issues to solve:
#  quoting
#  parens

sub puke(@);
sub belch(@);

# for each operator type (key in %type_table), there
# should be a handler with the same name

my $ineq_op = '<>';
my $array_op = '-or';
my $hash_op = '-and';
my $implicit_eq_op = '=';

my %type_table = (
  infix_binary => [qw{
		       - / % -in =~ = <> < > <= >=
		       -contains -starts_with -ends_with}],
  infix_distributable => [qw{ + * -and -or }],
  prefix => [qw{ -not }],
  postfix => [qw{ -is_null -is_not_null }],
  function => [qw{
		   ()
		   -abs -ceil -floor -rand -round -sign
		   -e -exp -log -log10 -sqrt -acos -asin -atan -atan2
		   -cos -cot -haversin -pi -radians -sin -tan
		   -left -lower -ltrim -replace -reverse -right
		   -rtrim -split -substring -toString -trim -upper
		   -length -size -type -id -coalesce -head -last
		   -labels -nodes -relationships -keys -tail -range}],
  predicate => [qw{ -all -any -none -single -filter}],
  extract => [qw{ -extract }],
  reduce => [qw{ -reduce }],
  list => [qw( -list )], # returns args in list format
 );

my %dispatch;
foreach my $type (keys %type_table) {
  no strict 'refs';
  my @ops = @{$type_table{$type}};
  @dispatch{@ops} = ( *${type}{CODE} ) x @ops;
}

sub new {
  my $class = shift;
  my ($dispatch) = @_ || \%dispatch;
  if ($dispatch and !(ref $dispatch eq 'HASH')) {
    puke "arg1 must be hashref mapping operators to coderefs (or absent)"
  }
  my $self = {
    dispatch => $dispatch || {}
   };
  bless $self, $class;
}

sub belch (@) {
  my($func) = (caller(1))[3];
  Carp::carp "[$func] Warning: ", @_;
}

sub puke (@) {
  my($func) = (caller(1))[3];
  Carp::croak "[$func] Fatal: ", @_;
}

sub infix_binary {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  unless ( @$args == 2 ) {
    puke "For $op, arg2 must have length 2";
  }
  return join(" ", $$args[0], _write_op($op), $$args[1]);
}

sub infix_distributable {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  $op = _write_op($op);
  return join(" $op ", @$args);
}

sub prefix {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  unless (@$args == 1) {
    puke "For $op, arg2 must have length 1"
  }
  return _write_op($op)." ".$$args[0];
}

sub postfix {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  unless (@$args == 1) {
    puke "For $op, arg2 must have length 1"
  }
  return $$args[0]." "._write_op($op);
}

sub function {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  return _write_op($op).'('.join(',',@$args).')';
}

sub predicate {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  unless ( @$args == 3 ) {
    puke "For $op, arg2 must have length 3";
  }
  return _write_op($op)."("."$$args[0] IN $$args[1] WHERE $$args[2]".")";
}

sub extract {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  unless ( @$args == 3 ) {
    puke "For $op, arg2 must have length 3";
  }
  return _write_op($op)."("."$$args[0] IN $$args[1] | $$args[2]".")";
}

sub reduce {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  unless ( @$args == 5 ) {
    puke "For $op, arg2 must have length 5";
  }
  return _write_op($op)."("."$$args[0] = $$args[1], $$args[2] IN $$args[3] | $$args[4]".")";
}

sub list {
  my ($op, $args) = @_;
  unless ($op and $args and !ref($op)
	    and ref($args) eq 'ARRAY'){
    puke "arg1 must be scalar, arg2 must be arrayref";
  }
  return "[".join(',',@$args)."]";
}

sub _write_op {
  my ($op) = @_;
  $op =~ s/^-//;
  my $c = (caller(1))[3];
  return '' if ($op eq '()');
  return join(' ', map { ($c=~/infix|prefix|postfix/) ? uc $_ : $_ } split /_/,$op);
}

# canonize - rewrite mixed hash/array expressions in canonical array format
# interpret like SQL::A
sub canonize {
  my $self = shift;
  my ($expr) = @_;
  my $ret = [];
  my ($do,$is_op);
  $is_op = sub {
    if (!$_[1]) {
      defined $self->{dispatch}{$_[0]};
    }
    else {
      grep /^$_[0]$/, @{$type_table{$_[1]}};
    }
  };
  $do = sub {
    my ($expr, $lhs) = @_;
    for (ref $expr) {
      ($_ eq '') && do {
	if (defined $expr) {
	  return $expr # literal
	}
	else {
	  puke "undef not interpretable";
	}
      };
      /REF|SCALAR/ && do { # literals
	($_ eq 'SCALAR') && return $$expr; # literal
	(ref $$expr eq 'ARRAY') && return $$expr->[0]; # literal ???
      };
      /ARRAY/ && do {
	if ($is_op->($$expr[0])) {
	  # op
	  return [ $$expr[0] => map { $do->($_) } @$expr[1..$#$expr] ];
	}
	elsif (ref $$expr[0] eq 'HASH') { #?
	  return [ $array_op => map { $do->{$_} } @$expr ];
	}
	else { # is a plain list
	  if ($lhs) {
	    # implicit equality over array default op
	    return [ $array_op => map {
	      defined ?
		[ '=', $lhs, $do->($_) ] :
		  [ -is_null => $lhs ]
	    } @$expr ];
	  }
	  else {
	    return [ -list => map { $do->($_) } @$expr ];
	  }
	}
      };
      /HASH/ && do {
	my @k = keys %$expr;
	if (@k == 1) {
	  my $k = $k[0];
	  # single hashpair
	  if ($is_op->($k)) {
	    $is_op->($k,'infix_binary') && do {
	      puke "Expected LHS for $k" unless $lhs;
	      if (defined $$expr{$k}) {
		return [ $k => $lhs, $do->($$expr{$k}) ];
	      }
	      else { # IS NOT NULL
		puke "Can't handle undef as argument to $k" unless
		  $k eq $ineq_op;
		return [ -is_not_null => $lhs ];
	      }
	    };
	    $is_op->($k,'function') && do {
	      return [ $k => $do->($$expr{$k}) ];
	    };
	    puke "Operator $k not expected";
	  }
	  elsif (ref($$expr{$k}) &&
		   ref($$expr{$k}) ne 'REF') {
	    # $k is an LHS
	    return $do->($$expr{$k}, $k);
	  }
	  else {
	    # implicit equality
	    if (defined $$expr{$k}) {
	      return [ $implicit_eq_op => $do->($$expr{$k}, $k) ];
	    }
	    else { # IS NULL
	      return [ -is_null => $k ];
	    }
	  }
	}
	else {
	  # >1 hashpair
	  # all keys are ops, or none is - otherwise barf
	  if ( all { $is_op->($_, 'infix_binary') } @k ) {
	    puke "No LHS provided for implict $hash_op" unless defined $lhs;
	    # distribute lhs over infix-rhs, combine with $hash_op
	    return [ $hash_op => map {
	      [ $_ => $lhs, $do->($$expr{$_}) ]
	    } @k ];
	  }
	  elsif ( none { $is_op->($_) } @k ) {
	    # distribute $hash_op over implicit equality
	    return [ $hash_op => map {
	      defined $$expr{$_} ? 
		[ $implicit_eq_op => $_, $do->($$expr{$_}) ] :
		[ -is_null => $_ ]
	    } @k ];
	  }
	  else {
	    puke "Can't handle mix of ops and non-ops in hash keys";
	  }
	}
      };
    }
  };
  $ret = $do->($expr);
  return $ret;
}

# peel - recurse $args = [ -op, @args ] to create complete production
sub peel {
  my ($self, $args) = @_;

  if (!defined $args) {
    return '';
  }
  elsif (!ref $args) { # single literal argument
    return $args;
  }
  elsif (ref $args eq 'ARRAY') {
    return '' unless (@$args);
    my $op = shift @$args;
    puke "'$op' : unknown operator" unless $self->{dispatch}{$op};
    my $expr = $self->{dispatch}{$op}->( $op, [map { $self->peel($_) } @$args] );
    if (grep /\Q$op\E/, @{$type_table{infix_distributable}}) {
      # group
      return "($expr)"
    }
    else {
      return $expr;
    }
  }
  else {
    puke "Can only peel() arrayrefs or scalar literals";
  }
}

1;
