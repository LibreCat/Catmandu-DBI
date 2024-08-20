requires 'perl','5.10.1';
requires 'Catmandu','>=1.0';
requires 'namespace::clean','>=0.24';
requires 'DBI','>=1.630';
requires 'Moo', '>=1.004006';
requires 'MooX::Aliases', '>=0.001006';
requires 'JSON';
requires 'Type::Tiny';

recommends 'Type::Tiny::XS';

on 'test', sub {
    requires 'Test::Exception','0';
    requires 'Test::More','0';
};
