package Catmandu::Store::DBI::Handler;

use Catmandu::Sane;
use Moo::Role;
use namespace::clean;

our $VERSION = "0.09";

requires 'create_table';
requires 'add_row';

sub select_sql {
    my ($self, $bag, $start, $limit, $where) = @_;
    my $id_field   = $bag->mapping->{_id}->{column};
    my $q_id_field = $bag->_quote_id($id_field);

    my $sql = "SELECT * FROM " . $bag->_quote_id($bag->name);
    $sql .= " WHERE $where" if $where;

    my $default_order = $bag->default_order // $bag->store->default_order;

    if (defined $default_order) {
        if ($default_order eq 'ID') {
            $sql .= " ORDER BY $q_id_field";
        }
        elsif ($default_order eq 'NONE') {

            # no nothing
        }
        else {
            $sql .= " ORDER BY $default_order";
        }
    }
    $sql .= " LIMIT $limit OFFSET $start";
    $sql;
}

sub count_sql {
    my ($self, $bag, $start, $total, $where) = @_;
    my $name = $bag->name;

    return "SELECT COUNT(*) FROM " . $bag->_quote_id($name)
        unless $total || $start || $where;

    my $sql = "SELECT COUNT(*) FROM (SELECT * FROM " . $bag->_quote_id($name);
    if ($where) {
        $sql .= " WHERE $where";
    }
    if ($total) {
        $sql .= " LIMIT $total";
    }
    elsif ($start) {    # no offset without limit
        $sql .= " LIMIT " . $bag->_max_limit;
    }
    if ($start) {
        $sql .= " OFFSET $start";
    }
    $sql .= ") AS q";

    $sql;
}

1;

