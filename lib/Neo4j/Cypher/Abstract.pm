package Neo4j::Cypher::Abstract;
use lib '../../../lib';
use Neo4j::Cypher::Abstract::Peeler;
use strict;
use warnings;

sub new {
  my $class = shift;
  my $self = {};
  $self->{peeler} = Neo4j::Cypher::Abstract::Peeler->new();
  bless $self, $class;
}



1;
