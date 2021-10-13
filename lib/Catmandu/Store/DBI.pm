package Catmandu::Store::DBI;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use DBI;
use Catmandu::Store::DBI::Bag;
use Moo;
use MooX::Aliases;
use Catmandu::Error;
use namespace::clean;

our $VERSION = "0.11";

with 'Catmandu::Store';
with 'Catmandu::Transactional';

has data_source => (
    is       => 'ro',
    required => 1,
    alias    => 'dsn',
    trigger  => sub {
        my $ds = $_[0]->{data_source};
        $ds = $ds =~ /^DBI:/i ? $ds : "DBI:$ds";
        $_[0]->{data_source} = $ds;
    },
);
has username => (is => 'ro', default => sub {''}, alias => 'user');
has password => (is => 'ro', default => sub {''}, alias => 'pass');
has default_order           => (is => 'ro', default => sub {'ID'});
has handler                 => (is => 'lazy');
has _in_transaction         => (is => 'rw', writer => '_set_in_transaction',);
has _dbh => (is => 'lazy', builder => '_build_dbh', writer => '_set_dbh',);

# DEPRECATED methods. Were only invented to tackle of problem of reconnection
sub timeout {
    warn "method timeout has been replaced by auto reconnect";
}

sub has_timeout {
    warn "method has_timeout has been replaced by auto reconnect";
    0;
}

sub reconnect_after_timeout {
    warn "method reconnect_after_timeout has been replaced by auto reconnect";
}

sub handler_namespace {
    'Catmandu::Store::DBI::Handler';
}

sub _build_handler {
    my ($self) = @_;
    my $driver = $self->dbh->{Driver}{Name} // '';
    my $ns     = $self->handler_namespace;
    my $pkg;
    if ($driver =~ /pg/i) {
        $pkg = 'Pg';
    }
    elsif ($driver =~ /sqlite/i) {
        $pkg = 'SQLite';
    }
    elsif ($driver =~ /mysql/i) {
        $pkg = 'MySQL';
    }
    else {
        Catmandu::NotImplemented->throw(
            'Only Pg, SQLite and MySQL are supported.');
    }
    require_package($pkg, $ns)->new;
}

sub _build_dbh {
    my ($self) = @_;
    my $opts = {
        AutoCommit                       => 1,
        RaiseError                       => 1,
        mysql_auto_reconnect             => 1,
        mysql_enable_utf8                => 1,
        pg_utf8_strings                  => 1,
        sqlite_use_immediate_transaction => 1,
        sqlite_unicode                   => 1,
    };
    my $dbh
        = DBI->connect($self->data_source, $self->username, $self->password,
        $opts,);
    $dbh;
}

sub dbh {

    my $self = $_[0];
    my $dbh  = $self->_dbh;

    # reconnect when dbh is not set (should never happen)
    return $self->reconnect
        unless defined $dbh;

    # check validity of dbh
    # for performance reasons only check every second
    if ( defined( $self->{last_ping_t} ) ) {

        return $dbh if (time - $self->{last_ping_t}) < 1;

    }

    $self->{last_ping_t} = time;
    return $dbh if $dbh->ping;

    # one should never reconnect to a database during a transaction
    # because that would initiate a new transaction
    Catmandu::Error->throw("Connection to DBI backend lost, and cannot reconnect during a transaction")
        unless $dbh->{AutoCommit};

    # reconnect and return dbh
    # note: mysql_auto_reconnect only works when AutoCommit is 1
    $self->reconnect;

}

sub reconnect {

    my $self = $_[0];
    my $dbh  = $self->_dbh;
    $dbh->disconnect if defined($dbh);
    $self->_set_dbh($self->_build_dbh);
    $self->_dbh;

}

sub transaction {
    my ($self, $sub) = @_;

    if ($self->_in_transaction) {
        return $sub->();
    }

    my $dbh = $self->dbh;
    my @res;

    eval {
        $self->_set_in_transaction(1);
        $dbh->begin_work;
        @res = $sub->();
        $dbh->commit;
        $self->_set_in_transaction(0);
        1;
    } or do {
        my $err = $@;
        eval {$dbh->rollback};
        $self->_set_in_transaction(0);
        die $err;
    };

    @res;
}

sub DEMOLISH {
    my ($self) = @_;
    $self->{_dbh}->disconnect if $self->{_dbh};
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Catmandu::Store::DBI - A Catmandu::Store backed by DBI

=head1 VERSION

Version 0.0424

=head1 SYNOPSIS

    # From the command line
    $ catmandu import JSON to DBI --data_source SQLite:mydb.sqlite < data.json

    # Or via a configuration file
    $ cat catmandu.yml
    ---
    store:
       mydb:
         package: DBI
         options:
            data_source: "dbi:mysql:database=mydb"
            username: xyz
            password: xyz
    ...
    $ catmandu import JSON to mydb < data.json
    $ catmandu export mydb to YAML > data.yml
    $ catmandu export mydb --id 012E929E-FF44-11E6-B956-AE2804ED5190 to JSON > record.json
    $ catmandu count mydb
    $ catmandy delete mydb

    # From perl
    use Catmandu::Store::DBI;

    my $store = Catmandu::Store::DBI->new(
        data_source => 'DBI:mysql:database=mydb', # prefix "DBI:" optional
        username => 'xyz', # optional
        password => 'xyz', # optional
    );

    my $obj1 = $store->bag->add({ name => 'Patrick' });

    printf "obj1 stored as %s\n" , $obj1->{_id};

    # Force an id in the store
    my $obj2 = $store->bag->add({ _id => 'test123' , name => 'Nicolas' });

    my $obj3 = $store->bag->get('test123');

    $store->bag->delete('test123');

    $store->bag->delete_all;

    # All bags are iterators
    $store->bag->each(sub { ... });
    $store->bag->take(10)->each(sub { ... });

=head1 DESCRIPTION

A Catmandu::Store::DBI is a Perl package that can store data into
DBI backed databases. The database as a whole is  a 'store'
L<Catmandu::Store>. Databases tables are 'bags' (L<Catmandu::Bag>).

Databases need to be preconfigured for accepting Catmandu data. When
no specialized Catmandu tables exist in a database then Catmandu will
create them automatically. See  "DATABASE CONFIGURATION" below.

DO NOT USE Catmandu::Store::DBI on an existing database! Tables and
data can be deleted and changed.

=head1 LIMITATIONS

Currently only MySQL, Postgres and SQLite are supported. Text columns are also
assumed to be utf-8.

=head1 CONFIGURATION

=over

=item data_source

Required. The connection parameters to the database. See L<DBI> for more information.

Examples:

      dbi:mysql:foobar   <= a local mysql database 'foobar'
      dbi:Pg:dbname=foobar;host=myserver.org;port=5432 <= a remote PostGres database
      dbi:SQLite:mydb.sqlite <= a local SQLLite file based database mydb.sqlite
      dbi:Oracle:host=myserver.org;sid=data01 <= a remote Oracle database

Drivers for each database need to be available on your computer. Install then with:

    cpanm DBD::mysql
    cpanm DBD::Pg
    cpanm DBD::SQLite

=item user

Optional. A user name to connect to the database

=item password

Optional. A password for connecting to the database

=item default_order

Optional. Default the default sorting of results when returning an iterator.
Choose 'ID' to order on the configured identifier field, 'NONE' to skip all
ordering, or "$field" where $field is the name of a table column. By default
set to 'ID'.

=back

=head1 DATABASE CONFIGURATION

When no tables exists for storing data in the database, then Catmandu
will create them. By default tables are created for each L<Catmandu::Bag>
which contain an '_id' and 'data' column.

This behavior can be changed with mapping option:

    my $store = Catmandu::Store::DBI->new(
        data_source => 'DBI:mysql:database=test',
        bags => {
            # books table
            books => {
                mapping => {
                    # these keys will be directly mapped to columns
                    # all other keys will be serialized in the data column
                    title => {type => 'string', required => 1, column => 'book_title'},
                    isbn => {type => 'string', unique => 1},
                    authors => {type => 'string', array => 1}
                }
            }
        }
    );

For keys that have a corresponding table column configured, the method 'select' of class L<Catmandu::Store::DBI::Bag> provides
a more efficiënt way to query records.

See L<Catmandu::Store::DBI::Bag> for more information.

=head2 Column types

=over

=item string

=item integer

=item binary

=item datetime

Only MySQL, PostgreSQL

=item datetime_milli

Only MySQL, PostgreSQL

=item json

Only PostgreSQL

This is mapped internally to postgres field of type "jsonb".

Please use the serializer L<Catmandu::Serializer::json_string>,

if you choose to store the perl data structure into this type of field.

Reasons:

* there are several types of serializers. E.g. serializer "messagepack"
  produces a string that is not accepted by a jsonb field in postgres

* the default serializer L<Catmandu::Serializer::json> converts the perl data structure to a binary json string,
  and the DBI client reencodes that utf8 string (because jsonb is a sort of text field),
  so you end up having a double encoded string.

=back

=head2 Column options

=over

=item column

Name of the table column if it differs from the key in your data.

=item array

Boolean option, default is C<0>. Note that this is only supported for PostgreSQL.

=item unique

Boolean option, default is C<0>.

=item index

Boolean option, default is C<0>. Ignored if C<unique> is true.

=item required

Boolean option, default is C<0>.

=back

=head1 AUTO RECONNECT

This library automatically connects to the underlying

database, and reconnects when that connection is lost.

There is one exception though: when the connection is lost

in the middle of a transaction, this is skipped and

a L<Catmandu::Error> is thrown. Reconnecting during a

transaction would have returned a new transaction,

and (probably?) committed the lost transaction

contrary to your expectation. There is actually no way to

recover from that, so throwing an error seemed

liked to a "good" way to solve that.


In order to avoid this situation, try to avoid

a big time lap between database actions during

a transaction, as your server may have thrown

you out.

P.S. the mysql option C<< mysql_auto_reconnect >>

does NOT automatically reconnect during a transaction

exactly for this reason.

=head1 SEE ALSO

L<Catmandu::Bag>, L<DBI>

=cut
