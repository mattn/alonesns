#!perl
use strict;
use warnings;

use Mojolicious::Lite;
use DBI;
use SQL::Maker;
use File::Basename;
use File::Spec;

my $config = do File::Spec->catfile(dirname(__FILE__), 'config.pl')
  or die "config.pl not exists";

my $dbi = $config->{DBI};
my ($_, $driver) = DBI->parse_dsn($dbi->[0]);

my $dbh = DBI->connect(@$dbi);
my $builder = SQL::Maker->new(driver => $driver);

sub config {
  my $table = shift;
  my $tc = $config->{tables}->{$table};
  return unless $tc;
  $tc->{fields} = ['*'] unless $tc->{fields};
  $tc->{options} = +{limit => 10} unless $tc->{options};
  $tc->{defaults} = +{} unless $tc->{defaults};
  $tc->{primary_keys} = [] unless $tc->{primary_keys};
  $tc->{protected_keys} = [] unless $tc->{protected_keys};
  $tc;
}

get '/:table' => sub {
  my $self = shift;

  my $table = $self->param('table');
  my $tc = config($table) or return $self->render_not_found;

  my $offset = $self->req->headers->header('x-row-offset');
  $tc->{options}->{offset} = $offset if $offset;
  my $limit = $self->req->headers->header('x-row-limit');
  $tc->{options}->{limit} = $limit if $limit;

  my $query = $self->req->url->query->to_hash;

  for (@{$tc->{protected_keys}}) {
    return $self->render_exception('Oops!') if $query->{$_};
  }

  my ($sql, @binds) = $builder->select(
    $table,
    $tc->{fields},
    $query,
    $tc->{options});

  my $rows = $dbh->selectall_arrayref($sql, {Slice => +{}}, @binds);
  $self->respond_to(
    json => {json => $rows},
    html => sub {
      $self->stash(result => $rows);
      $self->render(template => 'table');
    }
  );
};

post '/:table' => sub {
  my $self = shift;

  my $table = $self->param('table');
  my $tc = config($table) or return $self->render_not_found;

  my $params = $self->req->body_params->to_hash;

  for (@{$tc->{protected_keys}}) {
    return $self->render_exception('Oops!') if $params->{$_};
  }

  while (my ($key, $value) = each(%{$tc->{defaults}})) {
    next if $params->{$key};
    utf8::decode($value) if $value && !utf8::is_utf8($value);
    $params->{$key} = $value;
  }
  my ($sql, @binds) = $builder->insert($self->param('table'), $params);
  my $res = $dbh->do($sql, undef, @binds);
  $self->respond_to(
    any  => {json => {res => $res}},
  );
};

put '/:table' => sub {
  my $self = shift;

  my $table = $self->param('table');
  my $tc = config($table) or return $self->render_not_found;

  my $query = $self->req->url->to_hash;
  my $params = $self->req->body_params->to_hash;

  for (@{$tc->{primary_keys}}) {
    return $self->render_exception('Oops!') unless $query->{$_};
  }
  for (@{$tc->{protected_keys}}) {
    return $self->render_exception('Oops!') if $params->{$_};
  }

  my ($sql, @binds) = $builder->update($table, $params, $query);
  my $res = $dbh->do($sql, undef, @binds);
  $self->respond_to(
    any  => {json => {res => $res}},
  );
};

del '/:table' => sub {
  my $self = shift;

  my $table = $self->param('table');
  my $tc = config($table) or return $self->render_not_found;

  my $query = $self->req->url->query->to_hash;

  for (@{$tc->{primary_keys}}) {
    return $self->render_exception('Oops!') unless $query->{$_};
  }
  for (@{$tc->{protected_keys}}) {
    return $self->render_exception('Oops!') if $query->{$_};
  }

  my ($sql, @binds) = $builder->delete($table, $query);
  my $res = $dbh->do($sql, undef, @binds);
  $self->respond_to(
    any  => {json => {res => $res}},
  );
};

get '/' => 'index';

app->start;

__DATA__

@@ table.html.ep
<!DOCTYPE HTML>
<html>
<head>
<meta charset="UTF-8">
<title>database utility</title>
<style type="text/css">
td { min-width: 100px; }
</style>
</head>
<body>
% if ($result && $result->[0]) {
<table border="1">
  <tr>
% for my $key (sort keys $result->[0]) {
    <th><%= $key %></th>
% }
  </tr>
% for my $row (@{$result}) {
  <tr>
% for my $col (sort keys $row) {
    <td><%= $row->{$col} %></td>
% }
  </tr>
% }
</table>
%} else {
Not available.
%}
</body>
</html>

@@ not_found.json.ep
{"error": "Not Found"}

@@ exception.json.ep
{"error": "<%= $exception %>"}
