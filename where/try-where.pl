use lib 'lib';
use SQL::Abstract;
use strict;

# limitations
# want to express functions (rather than statements/keywords)
# generically:
{
  'a.name' => {
    -extract => ['x',
		 {
		   -coalesce => ['a', { -head => 'b' }, 'c']
		 },
		 'x.name']
   }
};
#  a.name = extract( x IN coalesce(a,head(b),c) | x.name )

# add other binary (distributable) ops (besides and and or):
# - XOR, +, -, * , /, %, ^
# add STARTS WITH, ENDS WITH, CONTAINS string ops
# deal with the property operator ( . ) - infix binary
# handle cypher lists ( surrounded by [] ) appropriately
# weird syntax functions: extract, filter, reduce
# all( var IN list WHERE pred )
# any( var IN list WHERE pred )
# none( var IN list WHERE pred )
# single( var IN list WHERE pred )
# extract( var IN list | expr)
# filter( var IN list WHERE pred)
# reduce ( acc = init, var IN list | expr )
# timestamp() - no arg
# e() - no arg
# pi() - no arg



my $functions = {
  predicate => [qw/all any exists none single/],
  scalar => { list_domain => [qw/coalesce head last size/],
	      scalar_domain => [qw/endNode id length properties startNode
				 timestamp toInt toFloat type/] },
  list => [ qw/extract filter keys labels nodes range reduce
	       relationships tail/ ],
  math => {
    numeric => [qw/abs ceil floor rand round sign/],
    log => [qw/e exp log log10 sqrt/],
    trig => [qw/acos asin atan atan2 cos cot haversin pi radians
		sin tan/],
    string => [qw/left lower ltrim replace reverse right
		  rtrim split substring toString trim upper/],
  },
};

my @functions;
my $slurp;
$slurp = sub {
  while (my ($k,$v) = each %{$_[0]}) {
    if (ref $v eq 'ARRAY') {
      push @functions, @$v;
    }
    else {
      $slurp->($v);
    }
  }
};
$slurp->($functions);

# my $ld_re = join('|',@{$functions->{scalar}{list_domain}});
# $ld_re = qr/^$ld_re$/;
# my $sd_re = join('|',@{$functions->{scalar}{scalar_domain}});
# $sd_re = qr/^$sd_re$/;

my $sp_ops = [
  {
    regex => qr/^re$/,
    handler => sub {
      my ($self, $fld, $op, $arg) = @_;
      my $re = $self->_quote($arg);
      my $cql = "$fld =~ $re";
      return $cql;
    }
   },
   #  {
   #  regex => $ld_re,
   #  handler => sub {
   #    my ($self, $fld, $op, $arg) = @_;
   #    my $lhs = $self->{_nested_func_lhs};
   #    my ($self, $fld, $op, $arg) = @_;
   #    my $cql = '';
   #    if (!ref $arg or ref $arg =~ /Pattern/) {
   # 	$cql = "$op($arg)";
   #    }
   #    elsif (ref $arg eq 'ARRAY') {
   # 	$cql = "$op(".join(',',@$arg).")";
   #    }
   #    else {
   # 	SQL::Abstract::puke "$op cannot accept a ".ref($arg)." object";
   #    }
   #    return $cql;
   #  }
   # },
   #  {
   #  regex => $sd_re,
   #  handler => sub {
   #    my ($self, $op, $arg) = @_;
   #    my $cql = '';
   #    if (!ref $arg or ref $arg =~ /Pattern/) {
   # 	$cql = "$op($arg)";
   #    }
   #    else {
   # 	SQL::Abstract::puke "$op can take a scalar or pattern object";
   #    }
   #    return $cql;
   #  }
   # }

 ];

my $un_ops = [
   ];

my %options = (
  special_ops => $sp_ops,
#  unary_ops => $un_ops,
  functions => \@functions,
  quote_char => "'",
  escape_char => '\\\\',
  sqltrue => 'true',
  sqlfalse => 'false'
 );

my $s = SQL::Abstract->new(%options);

1;
