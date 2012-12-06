+{
  DBI => [
    'dbi:SQLite:./db/alonesns.db',
    '',
    '',
    {sqlite_unicode => 1},
  ],
  tables => {
    statuses => { 
      fields => ['*'],
      defaults => {
        user => 'きっと俺',
      },
      primary_keys => ['id'],
      protected_keys => ['created_at'],
      options => {
        order_by => 'created_at desc',
        limit => 10,
      },
    },
  },
}
