# NAME

Catmandu::DBI - Catmandu tools to communicate with DBI based interfaces

# SYNOPSIS

    # From the command line

    # Export data from a relational database
    $ catmandu convert DBI --dsn dbi:mysql:foobar --user foo --password bar --query "select * from table"

    # Import data into a relational database
    $ catmandu import JSON to DBI --data_source dbi:SQLite:mydb.sqlite < data.json

    # Export data from a relational database
    $ catmandu export DBI --data_source dbi:SQLite:mydb.sqlite to JSON

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

    # Export one record
    $ catmandu export mydb --id 012E929E-FF44-11E6-B956-AE2804ED5190 to JSON > record.json

    # Count the number of records
    $ catmandu count mydb

    # Delete data
    $ catmandy delete mydb

# MODULES

[Catmandu::Importer::DBI](https://metacpan.org/pod/Catmandu%3A%3AImporter%3A%3ADBI)

[Catmandu::Store::DBI](https://metacpan.org/pod/Catmandu%3A%3AStore%3A%3ADBI)

# AUTHORS

Nicolas Franck `<nicolas.franck at ugent.be>`

Patrick Hochstenbach `<patrick.hochstenbach at ugent.be>`

Vitali Peil `<vitali.peil at uni-bielefeld.de>`

Nicolas Steenlant `<nicolas.steenlant at ugent.be>`

# COPYRIGHT

Copyright 2024 - Nicolas Franck, Patrick Hochstenbach, Vitali Peil, Nicolas Steenlant

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[Catmandu](https://metacpan.org/pod/Catmandu), [Catmandu::Importer](https://metacpan.org/pod/Catmandu%3A%3AImporter) , [Catmandu::Store::DBI](https://metacpan.org/pod/Catmandu%3A%3AStore%3A%3ADBI)
