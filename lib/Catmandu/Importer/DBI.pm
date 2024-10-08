package Catmandu::Importer::DBI;

use Catmandu::Sane;
use Catmandu::Error;
use DBI;
use Moo;
use MooX::Aliases;
use Types::Standard qw(Str);
use Types::Common::String qw(NonEmptyStr);
use namespace::clean;
use feature qw(signatures);
no warnings qw(experimental::signatures);

our $VERSION = '0.13';

with 'Catmandu::Importer';

has data_source => (is => 'ro', isa => NonEmptyStr, required => 1, alias => 'dsn');
has username    => (is => 'ro', isa => Str, alias    => 'user');
has password    => (is => 'ro', isa => Str, alias    => 'pass');
has query       => (is => 'ro', isa => NonEmptyStr, required => 1);
has dbh =>
    (is => 'ro', init_arg => undef, lazy => 1, builder => '_build_dbh',);
has sth =>
    (is => 'ro', init_arg => undef, lazy => 1, builder => '_build_sth',);

sub _build_dbh ($self) {
    my $dbh = DBI->connect(
        $self->dsn,
        $self->user,
        $self->password,
        {
            AutoCommit                       => 1,
            RaiseError                       => 1,
            mysql_auto_reconnect             => 1,
            mysql_enable_utf8                => 1,
            pg_utf8_strings                  => 1,
            sqlite_use_immediate_transaction => 1,
            sqlite_unicode                   => 1,
        }
    ) or Catmandu::Error->throw($DBI::errstr);
    $dbh;
}

sub _build_sth ($self) {
    my $sth  = $self->dbh->prepare($self->query) or Catmandu::Error->throw($self->dbh->errstr);
    $sth->execute or Catmandu::Error->throw($sth->errstr);
    $sth;
}

sub generator ($self) {
    sub {
        $self->sth->fetchrow_hashref();
    };
}

sub DESTROY ($self) {
    $self->sth->finish;
    $self->dbh->disconnect;
}

=head1 NAME

Catmandu::Importer::DBI - Catmandu module to import data from any DBI source

=head1 LIMITATIONS

Text columns are assumed to be utf-8.

=head1 SYNOPSIS

 # From the command line 

 $ catmandu convert DBI --dsn dbi:mysql:foobar --user foo --password bar --query "select * from table"

 # From Perl code

 use Catmandu;

 my %attrs = (
        dsn => 'dbi:mysql:foobar' ,
        user => 'foo' ,
        password => 'bar' ,
        query => 'select * from table'
 );

 my $importer = Catmandu->importer('DBI',%attrs);

 # Optional set extra parameters on the database handle
 # $importer->dbh->{LongReadLen} = 1024 * 64;

 $importer->each(sub {
	my $row_hash = shift;
	...
 });

=head1 DESCRIPTION

This L<Catmandu::Importer> can be used to access data stored in a relational database.
Given a database handle and a SQL query an export of hits will be exported.

=head1 CONFIGURATION

=over

=item dsn

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
    cpanm DBD::Oracle

=item user

Optional. A user name to connect to the database

=item password

Optional. A password for connecting to the database

=item query

Required. An SQL query to be executed against the datbase. 

=back

=head1 SEE ALSO

L<Catmandu>, L<Catmandu::Importer> , L<Catmandu::Store::DBI>

=cut

1;
