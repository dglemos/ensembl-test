#!/usr/bin/env perl

package Bio::EnsEMBL::App::DumpTestSchema;

use 5.010;

use MooseX::App::Simple qw(Color);

use Bio::EnsEMBL::Test::MultiTestDB;
use DBIx::Class::Schema::Loader qw(make_schema_at);

option 'test_dir' => (
    is            => 'ro',
    isa           => 'Str',
    default       => sub { $ENV{PWD} },
    cmd_aliases   => [qw/test-dir testdir/],
    documentation => q[Directory containing MultiTestDB.conf],
    );

option 'species' => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'homo_sapiens',
    documentation => q[Species],
    );

option 'db_type' => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'core',
    cmd_aliases   => [qw/db-type dbtype/],
    documentation => q[Database type],
    );

option 'dump_schema' => (
    is            => 'ro',
    isa           => 'Bool',
    cmd_aliases   => [qw/dump-schema dumpschema/],
    documentation => q[Dump DBIC schema],
    );

option 'schema_class' => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'Bio::EnsEMBL::Test::Schema',
    cmd_aliases   => [qw/schema-class schemaclass/],
    documentation => q[Generated schema class],
    );

option 'schema_dir' => (
    is            => 'ro',
    isa           => 'Str',
    default       => sub { $ENV{PWD} },
    cmd_aliases   => [qw/schema-dir schemadir/],
    documentation => q[Directory for schema class dump],
    );

option 'ddl_dir' => (
    is            => 'ro',
    isa           => 'Str',
    default       => sub { $ENV{PWD} },
    cmd_aliases   => [qw/ddl-dir ddldir/],
    documentation => q[Directory for ddl output],
    );

option 'check_driver' => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'mysql',
    cmd_aliases   => [qw/check-driver checkdriver/],
    documentation => q[Source DBD driver check],
    );

has 'dbc' => (
    is   => 'rw',
    isa  => 'Bio::EnsEMBL::DBSQL::DBConnection',
    );

sub run {
    my ($self)  = @_;

    my $mdb = $self->get_MultiTestDB;
    my $dbc = $self->dbc($mdb->get_DBAdaptor($self->db_type)->dbc);

    my $driver = $dbc->driver;
    my $check_driver = $self->check_driver;
    die "Driver is '$driver' but expected '$check_driver'" unless $driver eq $check_driver;

    $self->make_schema;
    $self->create_ddl;

    return;
}

sub get_MultiTestDB {
    my ($self)  = @_;
    my $mdb = Bio::EnsEMBL::Test::MultiTestDB->new($self->species, $self->test_dir, 1);
    $mdb->load_database($self->db_type);
    $mdb->create_adaptor($self->db_type);
    return $mdb;
}

sub make_schema {
    my ($self) = @_;

    my $loader_options = { naming => 'current' };
    $loader_options->{dump_directory} = $self->schema_dir if $self->dump_schema;

    make_schema_at($self->schema_class, $loader_options, [ sub { $self->dbc->db_handle } ]);
}

sub create_ddl {
    my ($self) = @_;
    my $schema = $self->connected_schema;
    $schema->create_ddl_dir(['SQLite'],
                            '0.1',
                            $self->ddl_dir,
                            undef,  # pre-version
                            { add_drop_table => 0 },
        );
}

sub connected_schema {
    my ($self) = @_;
    return $self->schema_class->connect( [ sub { $self->dbc->db_handle } ] );
}

no Moose;

# End of module

package main;

my $result = Bio::EnsEMBL::App::DumpTestSchema->new_with_options->run;
exit ($result ? $result : 0);

# EOF