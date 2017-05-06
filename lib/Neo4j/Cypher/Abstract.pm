package Neo4j::Cypher::Abstract;
use lib '../../../lib';
use base Exporter;
use Neo4j::Cypher::Pattern qw/pattern ptn/;
use Neo4j::Cypher::Abstract::Peeler;
use Scalar::Util qw/blessed/;
use Carp;
use overload
  '""' => as_string,
  'cmp' => sub { "$_[0]" cmp "$_[1]" };
use strict;
use warnings;


our @EXPORT_OK = qw/cypher pattern ptn/;
our $AUTOLOAD;

sub puke(@);
sub belch(@);

# let an Abstract object keep its own stacks of clauses
# rather than clearing an existing Abstract object, get
# new objects from a factory = cypher() 

# create, create_unique, match, merge - patterns for args
# where, set - SQL::A like expression for argument (only assignments make
#  sense for set)
# for_each - third arg is a cypher write query

# 'as' - include in the string arguments : "n.name as name"

our %clause_table = (
  read => [qw/match optional_match where start/],
  write => [qw/create merge set delete remove foreach
	       detach_delete
	       on_create on_match
	       create_unique/],
  general => [qw/return order_by limit skip with unwind union
		 return_distinct with_distinct
		 call yield/],
  hint => [qw/using_index using_scan using_join/],
  load => [qw/load_csv load_csv_with_headers
	      using_periodic_commit/],
  schema => [qw/create_constraint drop_constraint
		create_index drop_index/],
  modifier => [qw/skip limit order_by/]
 );
our @all_clauses = ( map { @{$clause_table{$_}} } keys %clause_table );

sub new {
  my $class = shift;
  my $self = {};
  $self->{stack} = [];
  bless $self, $class;
}

sub cypher {
  Neo4j::Cypher::Abstract->new;
}
sub available_clauses {no warnings qw/once/; @__PACKAGE__::all_clauses }

sub bind_values { $_[0]->{bind_values} && @{$_[0]->{bind_values}} }
sub parameters { $_[0]->{parameters} && @{$_[0]->{parameters}} }

# specials

sub where {
  my $self = shift;
  puke "Need arg1 => expression" unless defined $_[0];
  my $arg = $_[0];
  $self->_add_clause('where',$arg);
}

sub union { $_[0]->_add_clause('union') }
sub union_all { $_[0]->_add_clause('union_all') }

sub order_by {
  my $self = shift;
  puke "Need arg1 => identifier" unless defined $_[0];
  my @args;
  while (my $a = shift) {
    if ($_[0] and $_[0] =~ /^(?:de|a)sc$/i) {
      push @args, "$a ".uc(shift());
    }
    else {
      push @args, $a;
    }
  }
  $self->_add_clause('order_by',@args);
}

sub unwind {
  my $self = shift;
  puke "need arg1 => list expr" unless $_[0];
  puke "need arg2 => list variable" unless ($_[1] && !ref($_[1]));
  $self->_add_clause('unwind',$_[0],'AS',$_[1]);
}

sub match {
  my $self = shift;
  # shortcut for a single node identifier, with labels
  if (@_==1 and $_[0] =~ /^[a-z][a-z0-9_:]*$/i) {
    $self->_add_clause('match',"($_[0])");
  }
  else {
    $self->_add_clause('match',@_);
  }
}

sub create {
  my $self = shift;
  # shortcut for a single node identifier, with labels
  if (@_==1 and $_[0] =~ /^[a-z][a-z0-9_:]*$/i) {
    $self->_add_clause('create',"($_[0])");
  }
  else {
    $self->_add_clause('create',@_);
  }
}

sub foreach {
  my $self = shift;
  puke "need arg1 => list variable" unless ($_[0] && !ref($_[0]));
  puke "need arg2 => list expr" unless $_[1];
  puke "need arg3 => cypher update stmt" unless $_[2];
  $self->_add_clause('foreach', $_[0],'IN',$_[1],'|',$_[2]);
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

#create_constraint_exist('node', 'label', 'property')

sub create_constraint_exist {
  my $self = shift;
  puke "need arg1 => node/reln pattern" unless defined $_[0];
  puke "need arg2 => label" if (!defined $_[1] || ref $_[1]);
  puke "need arg2 => property" if (!defined $_[2] || ref $_[2]);
  $self->_add_clause('create_constraint_on', "($_[0]:$_[1])", 'ASSERT',"exists($_[0].$_[2])");
}

# create_constraint_unique('node', 'label', 'property')
sub create_constraint_unique {
  my $self = shift;
  puke "need arg1 => node/reln pattern" unless defined $_[0];
  puke "need arg2 => label" if (!defined $_[1] || ref $_[1]);
  puke "need arg2 => property" if (!defined $_[2] || ref $_[2]);
  $self->_add_clause('create_constraint_on', "($_[0]:$_[1])", 'ASSERT',
		     "$_[0].$_[2]", 'IS UNIQUE');
}

# create_index('label' => 'property')
sub create_index {
  my $self = shift;
  puke "need arg1 => node label" if (!defined $_[0] || ref $_[0]);
  puke "need arg2 => node property" if (!defined $_[1] || ref $_[1]);
  $self->_add_clause('create_index','ON',":$_[0]($_[1])");
}

# drop_index('label'=>'property')
sub drop_index {
  my $self = shift;
  puke "need arg1 => node label" if (!defined $_[0] || ref $_[0]);
  puke "need arg2 => node property" if (!defined $_[1] || ref $_[1]);
  $self->_add_clause('drop_index','ON',":$_[0]($_[1])");
}

# using_index('identifier', 'label', 'property')
sub using_index {
  my $self = shift;
  puke "need arg1 => identifier" if (!defined $_[0] || ref $_[0]);
  puke "need arg2 => node label" if (!defined $_[1] || ref $_[1]);
  puke "need arg3 => node property" if (!defined $_[2] || ref $_[2]);
  $self->_add_clause('using_index',"$_[0]:$_[1]($_[2])");
}

# using_scan('identifier' => 'label')
sub using_scan {
  my $self = shift;
  puke "need arg1 => identifier" if (!defined $_[0] || ref $_[0]);
  puke "need arg2 => node label" if (!defined $_[1] || ref $_[1]);
  $self->_add_clause('using_scan',"$_[0]:$_[1]");
}

# using_join('identifier', ...)
sub using_join {
  my $self = shift;
  puke "need arg => identifier" if (!defined $_[0] || ref $_[0]);
  $self->_add_clause('using_join', 'ON', join(',',@_));
}

# everything winds up here
sub _add_clause {
  my $self = shift;
  my $clause = shift;
  $self->{dirty} = 1;
  my @clause;
  push @clause, $clause;
  if ( $clause =~ /^match|create|merge/ and 
	 @_==1 and $_[0] =~ /^[a-z][a-z0-9_:]*$/i) {
    push @clause, "($_[0])";
  }
  else {
    for (@_) {
      if (ref && !blessed($_)) {
	my $plr = Neo4j::Cypher::Abstract::Peeler->new();
	push @clause, $plr->express($_);
	# kludge
	if ($clause =~ /^set/) {
	  # removing enclosing parens from peel
	  $clause[-1] =~ s/^\s*\(//;
	  $clause[-1] =~ s/\)\s*$//;
	}
	push @{$self->{bind_values}}, $plr->bind_values;
	push @{$self->{parameters}}, $plr->parameters;
      }
      else {
	push @clause, $_;
	my @parms = m/(\$[a-z][a-z0-9]*)/ig;
	push @{$self->{parameters}}, @parms;
      }
    }
  }
  if ($clause =~ /^return|with|order|set|remove/) {
    # group args in array so they are separated by commas
    @clause = (shift @clause, [@clause]);
  }
  push @{$self->{stack}}, \@clause;
  return $self;
}

sub as_string {
  my $self = shift;
  return $self->{string} if ($self->{string} && !$self->{dirty});
  undef $self->{dirty};
  my @c;
  for (@{$self->{stack}}) {
    my ($kws, @arg) = @$_;
    $kws =~ s/_/ /g;
    for (@arg) {
      $_ = join(',',@$_) if ref eq 'ARRAY';
    }
    if ($kws =~ /foreach/i) { #kludge for FOREACH
      push @c, uc($kws)." (".join(' ',@arg).")";
    }
    else {
      push @c, join(' ',uc $kws, @arg);
    }
  }
  $self->{string} = join(' ',@c);
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

