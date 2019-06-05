package Catmandu::Store::DBI::Iterator;

use Catmandu::Sane;
use Catmandu::Util qw(is_value is_string is_array_ref);
use Moo;
use namespace::clean;

our $VERSION = "0.09";

with 'Catmandu::Iterable';

has bag   => (is => 'ro', required => 1);
has where => (is => 'ro');
has binds => (is => 'lazy');
has total => (is => 'ro');
has start => (is => 'lazy');
has limit => (is => 'lazy');

sub _build_binds {[]}
sub _build_start {0}

sub _build_limit {
    my ($self) = @_;
    my $limit  = 100;
    my $total  = $self->total;
    if (defined $total && $total < $limit) {
        $limit = $total;
    }
    $limit;
}

sub generator {
    my ($self)  = @_;
    my $bag     = $self->bag;
    my $store   = $self->bag->store_with_table;
    my $handler = $store->handler;
    my $binds   = $self->binds;
    my $total   = $self->total;
    my $start   = $self->start;
    my $limit   = $self->limit;
    my $where   = $self->where;

    sub {
        state $rows;

        return if defined $total && !$total;

        unless (defined $rows && @$rows) {
            my $dbh = $store->dbh;

#DO NOT USE prepare_cached as it holds previous data in memory, leading to a memory leak!
            my $sth
                = $dbh->prepare(
                $handler->select_sql($bag, $start, $limit, $where))
                or Catmandu::Error->throw($dbh->errstr);
            $sth->execute(@$binds) or Catmandu::Error->throw($sth->errstr);
            $rows = $sth->fetchall_arrayref({});
            $sth->finish;
            $start += $limit;
        }

        my $data = $bag->_row_to_data(shift(@$rows) // return);
        $total-- if defined $total;
        $data;
    };
}

sub count {
    my ($self) = @_;
    my $bag    = $self->bag;
    my $binds  = $self->binds;
    my $store  = $bag->store_with_table;
    my $dbh    = $store->dbh;
    my $sth    = $dbh->prepare_cached(
        $store->handler->count_sql(
            $bag, $self->start, $self->total, $self->where
        )
    ) or Catmandu::Error->throw($dbh->errstr);
    $sth->execute(@$binds) or Catmandu::Error->throw($sth->errstr);
    my ($n) = $sth->fetchrow_array;
    $sth->finish;
    $n;
}

sub slice {
    my ($self, $start, $total) = @_;
    ref($self)->new(
        {
            bag   => $self->bag,
            where => $self->where,
            binds => $self->binds,
            total => $total,
            start => $self->start + ($start // 0),
        }
    );
}

around select => sub {
    my ($orig, $self, $arg1, $arg2) = @_;
    my $mapping = $self->bag->mapping;

    if (   is_string($arg1)
        && $mapping->{$arg1}
        && (is_value($arg2) || is_array_ref($arg2)))
    {
        my $opts = $self->_scope($arg1, $arg2);
        return ref($self)->new($opts);
    }

    $self->$orig($arg1, $arg2);
};

around detect => sub {
    my ($orig, $self, $arg1, $arg2) = @_;
    my $mapping = $self->bag->mapping;

    if (   is_string($arg1)
        && $mapping->{$arg1}
        && (is_value($arg2) || is_array_ref($arg2)))
    {
        my $opts = $self->_scope($arg1, $arg2);
        $opts->{total} = 1;
        return ref($self)->new($opts)->generator->();
    }

    $self->$orig($arg1, $arg2);
};

sub first {
    my ($self) = @_;
    ref($self)->new(
        {
            bag   => $self->bag,
            where => $self->where,
            binds => $self->binds,
            total => 1,
            start => $self->start,
        }
    )->generator->();
}

sub _scope {
    my ($self, $arg1, $arg2) = @_;
    my $binds  = [@{$self->binds}];
    my $where  = is_string($self->where) ? '(' . $self->where . ') AND ' : '';
    my $map    = $self->bag->mapping->{$arg1};
    my $column = $map->{column};
    my $q_column = $self->bag->_quote_id($column);

    if ($map->{array}) {
        push @$binds, is_value($arg2) ? [$arg2] : $arg2;
        $where .= "($q_column && ?)";
    }
    elsif (is_value($arg2)) {
        push @$binds, $arg2;
        $where .= "($q_column=?)";
    }
    else {
        push @$binds, @$arg2;
        $where .= "($q_column IN(" . join(',', ('?') x @$arg2) . '))';
    }

    {
        bag   => $self->bag,
        where => $where,
        binds => $binds,
        start => $self->start,
    };
}

1;
