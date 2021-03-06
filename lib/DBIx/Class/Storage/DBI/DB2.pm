package DBIx::Class::Storage::DBI::DB2;

use strict;
use warnings;

use base qw/DBIx::Class::Storage::DBI/;
use mro 'c3';

__PACKAGE__->sql_limit_dialect ('RowNumberOver');
__PACKAGE__->sql_quote_char ('"');
__PACKAGE__->datetime_parser_type('DateTime::Format::DB2');

sub _dbh_last_insert_id {
    my ($self, $dbh, $source, $col) = @_;

    my $sth = $dbh->prepare_cached('VALUES(IDENTITY_VAL_LOCAL())', {}, 3);
    $sth->execute();

    my @res = $sth->fetchrow_array();

    return @res ? $res[0] : undef;
}


1;

=head1 NAME

DBIx::Class::Storage::DBI::DB2 - Automatic primary key class for DB2

=head1 SYNOPSIS

  # In your table classes
  use base 'DBIx::Class::Core';
  __PACKAGE__->set_primary_key('id');

=head1 DESCRIPTION

This class implements autoincrements for DB2.

=head1 AUTHORS

Jess Robinson

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
