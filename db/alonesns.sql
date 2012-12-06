create table statuses (
  id integer primary key,
  user text,
  text text,
  created_at datetime default (datetime('now','localtime'))
);
