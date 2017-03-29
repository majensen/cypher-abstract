package Neo4j::Cypher::Abstract;
use Carp;
use strict;
use warnings;

# issues to solve:
#  quoting
#  parens
my %dispatch;
my @infix_binary = qw{
 - / % -in =~ = <> < > <= >=
 -contains -starts_with -ends_with
};
my @infix_distributable = qw{ + * -and -or };
my @prefix = qw{ -not };
my @postfix = qw{ -is_null -is_not_null };
my @function = qw{
    -abs -ceil -floor -rand -round -sign
    -e -exp -log -log10 -sqrt -acos -asin -atan -atan2
    -cos -cot -haversin -pi -radians -sin -tan
    -left -lower -ltrim -replace -reverse -right
    -rtrim -split -substring -toString -trim -upper
 };

@dispatch{@infix_binary} = (\&infix_binary) x @infix_binary;
@dispatch{@infix_distributable} = (\&infix_distributable) x @infix_distributable;
@dispatch{@prefix} = (\&prefix) x @prefix;
@dispatch{@postfix} = (\&postfix) x @postfix;
@dispatch{@function} = (\&function) x @function;

sub new {
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

sub _write_op {
  my ($op) = @_;
  $op =~ s/^-//;
  my $c = (caller(1))[3];
  return join(' ', map { ($c=~/function/) ? $_ : uc $_ } split /_/,$op);
}
1;

package Neo4j::Cypher::Abstract::Peel;
use Carp;
use strict;
use warnings;

sub belch (@) {
  my($func) = (caller(1))[3];
  Carp::carp "[$func] Warning: ", @_;
}

sub puke (@) {
  my($func) = (caller(1))[3];
  Carp::croak "[$func] Fatal: ", @_;
}

sub new {
  my $class = shift;
  my ($dispatch) = @_;
  if ($dispatch and !(ref $dispatch eq 'HASH')) {
    puke "arg1 must be hashref mapping operators to coderefs (or absent)"
  }
  my $self = {
    dispatch => $dispatch || {}
   };
  bless $self, $class;
}

# peel - recurse $args = [ -op, @args ] to create complete production
sub peel {
  my ($self, $args) = @_;
  #  state @acc;
  return unless defined $args;
  if (!ref $args) { # single literal argument
    return $args;
  }
  elsif (ref $args eq 'ARRAY') {
    my $op = shift @$args;
    puke "'$op' : unknown operator" unless $self->{dispatch}{$op};
    return $self->{dispatch}{$op}->( $op, [map { $self->peel($_) } @$args] );
  }
  else {
    puke "Can only peel() arrayrefs or scalar literals";
  }
}


1;
