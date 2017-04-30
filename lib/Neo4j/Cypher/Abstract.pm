package Neo4j::Cypher::Abstract;
use lib '../../../lib';
use base Exporter;
use Neo4j::Cypher::Pattern qw/pattern/;
use Neo4j::Cypher::Abstract::Peeler;
use Carp;
use overload
  '""' => as_string;
use strict;
use warnings;

our @EXPORT_OK = qw/cypher pattern/;
our $AUTOLOAD;

sub puke(@);
sub belch(@);

# let an Abstract object keep its own stacks of clauses
# rather than clearing an existing Abstract object, get
# new objects from a factory

# create, create_unique, match, merge - patterns for args
# where, set - SQL::A like expression for argument (only assignments make
#  sense for set)
# for_each - third arg is a cypher write query

our %clause_table = (
  read => [qw/match optional_match where start/],
  write => [qw/create merge set delete remove foreach
	       detach_delete
	       on_create on_match
	       create_unique/],
  general => [qw/return order_by limit skip with unwind union
		 return_distinct
		 call yield/],
  hint => [qw/using_index using_scan using_join/],
  load => [qw/load_csv load_csv_with_headers
	      using_periodic_commit/],
  schema => [qw/create_constraint drop_constraint
		create_index drop_index/],
  modifier => [qw/skip limit order_by/]
 );
our @all_clauses = ( map { @{$clause_table{$_}} } keys %clause_table );
our $PEELER = Neo4j::Cypher::Abstract::Peeler->new();

sub new {
  my $class = shift;
  my $self = {};
  $self->{stack} = [];
  bless $self, $class;
}

sub cypher {
  Neo4j::Cypher::Abstract->new;
}

sub bind_values { $_[0]->{bind_values} && @{$_[0]->{bind_values}} }
sub parameters { $_[0]->{parameters} && @{$_[0]->{parameters}} }

# specials

sub where {
  my $self = shift;
  puke "Need arg1 => expression" unless defined $_[0];
  my $arg = $_[0];
  if (ref $arg) {
    $arg = $PEELER->express($arg);
    $self->{bind_values} = [$PEELER->bind_values];
    $self->{parameters} = [$PEELER->parameters];
  }
  $self->_add_clause('where',$arg);
}

sub set {
  my $self = shift;
  puke "Need arg1 => assignment expression" unless defined $_[0];
  my $arg = $_[0];
  if (ref $arg) {
    $arg = $PEELER->express($arg);
  }
  $self->_add_clause('set',$arg);
}

sub union { $_[0]->_add_clause('union') }
sub union_all { $_[0]->_add_clause('union_all') }

sub order_by {
  my $self = shift;
  puke "Need arg1 => identifier" unless defined $_[0]
  puke "Need 'asc' or 'desc', not '$_[1]'" if ($_[1] and $_[1] !~ /^asc|desc$/i);
  $self->_add_clause('order_by',@_);
}

sub unwind {
  my $self = shift;
  puke "need arg1 => list expr" unless $_[0];
  puke "need arg2 => list variable" unless ($_[1] && !ref($_[1]));
  $self->_add_clause('unwind',$_[0],'AS',$_[1]);
}

sub return {
  my $self = shift;
  $self->_add_clause('return', join(',',@_));
}

sub for_each {
  my $self = shift;
  puke "need arg1 => list variable" unless ($_[0] && !ref($_[0]));
  puke "need arg2 => list expr" unless $_[1];
  puke "need arg3 => cypher update stmt" unless $_[2];
  $self->_add_clause('for_each', $_[0],'IN',$_[1],'|',$_[2]);
}

sub load_csv {
  my $self = shift;
  puke "need arg1 => file location" unless $_[0];
  puke "need arg2 => identifier" if (!defined $_[1] || ref $_[1]);
  $self->_add_clause('load_csv','FROM',$_[0],'AS',$_[1]);
}

sub load_csv_with_headers {
  my $self = shift;
  puke "need arg1 => file location" unless $_[0];
  puke "need arg2 => identifier" if (!defined $_[1] || ref $_[1]);
  $self->_add_clause('load_csv_with_headers','FROM',$_[0],'AS',$_[1]);
}

sub create_index {
  my $self = shift;
  puke "need arg1 => node label" if (!defined $_[0] || ref $_[0]);
  puke "need arg2 => node property" if (!defined $_[1] || ref $_[1]);
  $self->_add_clause('create_index','ON',":$_[0]($_[1])");
}

sub drop_index {
  my $self = shift;
  puke "need arg1 => node label" if (!defined $_[0] || ref $_[0]);
  puke "need arg2 => node property" if (!defined $_[1] || ref $_[1]);
  $self->_add_clause('drop_index','ON',":$_[0]($_[1])");
}


# everything winds up here
sub _add_clause {
  my $self = shift;
  my $clause = shift;
  $self->{dirty} = 1;
  push @{$self->{stack}}, [$clause, @_];
  return $self;
}

sub as_string {
  my $self = shift;
  return $self->{string} if ($self->{string} && !$self->{dirty});
  undef $self->{dirty};
  my $kw = $$_[0];
  $kw =~ s/_/ /g;
  $self->{string} = join(
    ' ',
    map {
      join(' ', uc $kw, @{$_}[1..$#$_]);
    } @{$self->{stack}}
   );
  $self->{string} =~ s/(\s)+/$1/g;
  return $self->{string};
}

sub AUTOLOAD {
  my $self = shift;
  my ($method) = $AUTOLOAD =~ /.*::(.*)/;
  unless (grep /$method/, @all_clauses) {
    puke "Unknown clause '$method'";
  }
  $self->_add_clause($method,@_);
}

sub belch (@) {
  my($func) = (caller(1))[3];
  Carp::carp "[$func] Warning: ", @_;
}

sub puke (@) {
  my($func) = (caller(1))[3];
  Carp::croak "[$func] Fatal: ", @_;
}

=head1 NAME

Neo4j::Cypher::Abstract - Generate Cypher query statements

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

1;

