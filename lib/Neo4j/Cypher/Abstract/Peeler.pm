package Neo4j::Cypher::Abstract::Peeler;
use Carp;
use strict;
use warnings;

# issues to solve:
#  quoting
#  parens

sub puke(@);
sub belch(@);

my @infix_binary = qw{
 - / % -in =~ = <> < > <= >=
 -contains -starts_with -ends_with};
my @infix_distributable = qw{ + * -and -or };
my @prefix = qw{ -not };
my @postfix = qw{ -is_null -is_not_null };
my @function = qw{
    ()
    -abs -ceil -floor -rand -round -sign
    -e -exp -log -log10 -sqrt -acos -asin -atan -atan2
    -cos -cot -haversin -pi -radians -sin -tan
    -left -lower -ltrim -replace -reverse -right
    -rtrim -split -substring -toString -trim -upper
    -length -size -type -id -coalesce -head -last
    -labels -nodes -relationships -keys -tail -range};
my @predicate = qw{ -all -any -none -single -filter};
my @extract = qw{ -extract };
my @reduce = qw{ -reduce };
my @list = qw{ -list }; # returns args in list format

my %dispatch;
@dispatch{@infix_binary} = (\&infix_binary) x @infix_binary;
@dispatch{@infix_distributable} = (\&infix_distributable) x @infix_distributable;
@dispatch{@prefix} = (\&prefix) x @prefix;
@dispatch{@postfix} = (\&postfix) x @postfix;
@dispatch{@function} = (\&function) x @function;
@dispatch{@predicate} = (\&predicate) x @predicate;
@dispatch{@extract} = (\&extract) x @extract;
@dispatch{@reduce} = (\&reduce) x @reduce;
@dispatch{@list} = (\&list) x @list;

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
  my $do;
  $do = sub {
    my ($expr) = @_;
    for (ref $expr) {
      !defined && do {
	return $expr # literal
      };
      /REF/ && do {
	return @$$expr; # literal
      };
      /ARRAY/ && do {
	if (defined $self->{dispatch}{$$expr[0])) { # op
	  return [ $$expr[0] => map { $do->($_) } @$expr[1..$#$expr] ];
	}
	else { # is a list
	  return [ -list => map { $do->($_) } @$expr ];
	}
      };
      /HASH/ && do { 
	for (keys
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
    if (grep /\Q$op\E/, @infix_distributable) {
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
