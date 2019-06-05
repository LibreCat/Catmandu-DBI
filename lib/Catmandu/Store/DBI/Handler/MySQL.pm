package Catmandu::Store::DBI::Handler::MySQL;

use Catmandu::Sane;
use Moo;
use namespace::clean;

our $VERSION = "0.09";

with 'Catmandu::Store::DBI::Handler';

# text types are case-insensitive in MySQL
sub _column_sql {
    my ($self, $map, $bag) = @_;
    my $col = $map->{column};
    my $dbh = $bag->store->dbh;
    my $sql = $dbh->quote_identifier($col) . " ";
    if ($map->{type} eq 'string' && $map->{unique}) {
        $sql .= 'VARCHAR(255) BINARY';
    }
    elsif ($map->{type} eq 'string') {
        $sql .= 'TEXT BINARY';
    }
    elsif ($map->{type} eq 'integer') {
        $sql .= 'INTEGER';
    }
    elsif ($map->{type} eq 'binary') {
        $sql .= 'LONGBLOB';
    }
    elsif ($map->{type} eq 'datetime') {
        $sql .= 'DATETIME';
    }
    elsif ($map->{type} eq 'datetime_milli') {
        if ($dbh->{mysql_clientversion} < 50640) {
            Catmandu::Error->throw(
                "DATETIME(3) type only supported in MySQL 5.6.4 and above");
        }
        $sql .= 'DATETIME(3)';
    }
    else {
        Catmandu::Error->throw("Unknown type '$map->{type}'");
    }
    if ($map->{unique}) {
        $sql .= " UNIQUE";
    }
    if ($map->{required}) {
        $sql .= " NOT NULL";
    }
    if (!$map->{unique} && $map->{index}) {
        if ($map->{type} eq 'string') {
            $sql .= ", INDEX($col(255))";
        }
        else {
            $sql .= ", INDEX($col)";
        }
    }
    $sql;
}

# http://devoluk.com/mysql-limit-offset-performance.html
sub select_sql {
    my ($self, $bag, $start, $limit, $where) = @_;

    my $q_id_field = $bag->_quote_id($bag->mapping->{_id}->{column});
    my $q_table    = $bag->_quote_id($bag->name);

    my $sql = "SELECT * FROM $q_table AS t1";
    $sql .= " JOIN (SELECT $q_id_field FROM $q_table";
    $sql .= " WHERE $where" if $where;

    my $default_order = $bag->default_order // $bag->store->default_order;

    if (defined $default_order && $default_order eq 'ID') {
        $sql .= " ORDER BY $q_id_field";
    }
    elsif (defined $default_order && $default_order ne 'NONE') {
        $sql .= " ORDER BY $default_order";
    }
    $sql
        .= " LIMIT $limit OFFSET $start) AS t2 ON t1.$q_id_field = t2.$q_id_field";

    $sql;
}

sub create_table {
    my ($self, $bag) = @_;
    my $mapping = $bag->mapping;
    my $dbh     = $bag->store->dbh;
    my $q_name  = $dbh->quote_identifier($bag->name);
    my $sql
        = "CREATE TABLE IF NOT EXISTS $q_name("
        . join(',', map {$self->_column_sql($_, $bag)} values %$mapping)
        . ")";
    $dbh->do($sql) or Catmandu::Error->throw($dbh->errstr);
}

sub add_row {
    my ($self, $bag, $row) = @_;
    my $dbh    = $bag->store->dbh;
    my @cols   = keys %$row;
    my @q_cols = map {$dbh->quote_identifier($_)} @cols;
    my @vals   = values %$row;
    my $q_name = $dbh->quote_identifier($bag->name);
    my $sql
        = "INSERT INTO $q_name("
        . join(',', @q_cols)
        . ") VALUES("
        . join(',', ('?') x @q_cols)
        . ") ON DUPLICATE KEY UPDATE "
        . join(',', map {"$_=VALUES($_)"} @q_cols);

    my $sth = $dbh->prepare_cached($sql)
        or Catmandu::Error->throw($dbh->errstr);
    $sth->execute(@vals) or Catmandu::Error->throw($sth->errstr);
    $sth->finish;
}

1;
