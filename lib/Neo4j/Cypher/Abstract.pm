package Neo4j::Cypher::Abstract;
use lib '../../../lib';
use base Exporter;
use Neo4j::Cypher::Pattern qw/pattern/;
use Neo4j::Cypher::Abstract::Peeler;
use Carp qw/croak carp/;
use overload
  '""' => as_string;
use strict;
use warnings;

our @EXPORT_OK = qw/cypher pattern/;
our $AUTOLOAD;
# let an Abstract object keep its own stacks of clauses
# rather than clearing an existing Abstract object, get
# new objects from a factory

our %clause_table = (
  read => [qw/match optional_match where start/],
  write => [qw/create merge set delete remove foreach
	       detach_delete
	       merge_on_create merge_on_match
	       create_unique/],
  general => [qw/return order_by limit skip with unwind union call yield/],
  hint => [qw/using_index using_scan using_join/],
  load => [qw/load_csv load_csv_using_periodic_commit/],
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

sub where {
  my $self = shift;
  my $arg = $_[0];
  if (ref $arg) {
    $arg = $PEELER->express($arg);
  }
  $self->_add_clause('where',$arg);
}

sub _add_clause {
  my $self = shift;
  my $clause = shift;
  my @args = @_;
  $self->{dirty} = 1;
  push @{$self->{stack}}, [$clause, @args];
  return $self;
}


sub as_string {
  my $self = shift;
  return $self->{string} if ($self->{string} && !$self->{dirty});
  undef $self->{dirty};
  $self->{string} = join(
    ' ',
    map {
      join(' ', uc $$_[0], @{$_}[1..$#$_])
    } @{$self->{stack}}
   )
}

sub AUTOLOAD {
  my $self = shift;
  my ($method) = $AUTOLOAD =~ /.*::(.*)/;
  unless (grep /$method/, @all_clauses) {
    croak "Unknown clause '$method'";
  }
  $self->_add_clause($method,@_);
}

1;

