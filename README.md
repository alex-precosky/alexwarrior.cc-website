# alexwarrior.cc

This is the source for the [alexwarrior.cc](http://alexwarrior.cc) website.

It is Drupal based and is deployed to DreamHost.

# Prerequisites

The build and deployment sites both need:
- PHP 8.4+
- Composer. Install via:

```
curl -sS https://getcomposer.org/installer | php
```

There also needs to be a mysql server accessible from the deployment host.

# Build/Deploy

One time setup:
- Copy file `deploy.config.sample` to `deploy.config`
- Enter real values the SSH host and mysql connection info placeholders

Then to deploy:

```
./deploy.sh
```

This does not deploy the database or web files - those must be restored from a
backup. The site should load at least and have content, and just have missing
images!

# Site Content Backup/Restore

From the server - backing up the mysql dataabse and web files, from `~/alexwarrior.cc`:

```
mysqldump -u precosky alexwarrior_drupal10 > alexwarrior_drupal_10_backup.sql
tar -czf alexwarrior_drupal_webfiles.tgz web/sites/default/files
```

To restore, from the `~/alexwarrior.cc`:

```
mysql -u precosky -p -h drupal.alexwarrior.cc alexwarrior_drupal10 < alexwarrior_drupal_10_backup.sql
tar -xvf alexwarrior_drupal_webfiles.tgz
```
