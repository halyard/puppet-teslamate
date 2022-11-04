# @summary Configure TeslaMate instance
#
# @param datadir handles storage of Postgres and MQTT data
# @param database_password sets the postgres password for teslamate
# @param encryption_key sets the key used to encrypt tesla API tokens
# @param teslamate_ip sets the IP of the teslamate container
# @param postgres_ip sets the IP of the postgres container
# @param mqtt_ip sets the IP of the mqtt container
# @param postgres_watchdog sets the watchdog URL for postgres dumps
# @param backup_target sets the target repo for backups
# @param backup_watchdog sets the watchdog URL to confirm backups are working
# @param backup_password sets the encryption key for backup snapshots
# @param backup_environment sets the env vars to use for backups
# @param backup_rclone sets the config for an rclone backend
class teslamate (
  String $datadir,
  String $database_password,
  String $encryption_key,
  String $teslamate_ip = '172.17.0.2',
  String $postgres_ip = '172.17.0.3',
  String $mqtt_ip = '172.17.0.4',
  Optional[String] $postgres_watchdog = undef,
  Optional[String] $backup_target = undef,
  Optional[String] $backup_watchdog = undef,
  Optional[String] $backup_password = undef,
  Optional[Hash[String, String]] $backup_environment = undef,
  Optional[String] $backup_rclone = undef,
) {
  firewall { '100 dnat for teslamate':
    chain  => 'DOCKER_EXPOSE',
    jump   => 'DNAT',
    proto  => 'tcp',
    dport  => 80,
    todest => "${teslamate_ip}:4000",
    table  => 'nat',
  }

  firewall { '100 dnat for postgres':
    chain  => 'DOCKER_EXPOSE',
    jump   => 'DNAT',
    proto  => 'tcp',
    dport  => 5432,
    todest => "${postgres_ip}:5432",
    table  => 'nat',
  }

  firewall { '100 dnat for mqtt':
    chain  => 'DOCKER_EXPOSE',
    jump   => 'DNAT',
    proto  => 'tcp',
    dport  => 1883,
    todest => "${mqtt_ip}:1883",
    table  => 'nat',
  }

  firewall { '101 allow cross container from teslamate to postgres':
    chain       => 'FORWARD',
    action      => 'accept',
    proto       => 'tcp',
    source      => $teslamate_ip,
    destination => $postgres_ip,
    dport       => 5432,
  }

  firewall { '101 allow cross container from teslamate to mqtt':
    chain       => 'FORWARD',
    action      => 'accept',
    proto       => 'tcp',
    source      => $teslamate_ip,
    destination => $mqtt_ip,
    dport       => 1883,
  }

  file { [
      $datadir,
      "${datadir}/backup",
      "${datadir}/postgres",
      "${datadir}/mqtt_config",
      "${datadir}/mqtt_data",
    ]:
      ensure => directory,
  }

  docker::container { 'postgres':
    image   => 'postgres:14',
    args    => [
      "--ip ${postgres_ip}",
      "-v ${datadir}/postgres:/var/lib/postgresql/data",
      '-e POSTGRES_USER=teslamate',
      "-e POSTGRES_PASSWORD=${database_password}",
      '-e POSTGRES_DB=teslamate',
    ],
    cmd     => '-c ssl=on -c ssl_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem -c ssl_key_file=/etc/ssl/private/ssl-cert-snakeoil.key',
    require => File["${datadir}/postgres"],
  }

  docker::container { 'mqtt':
    image   => 'eclipse-mosquitto:2',
    args    => [
      "--ip ${mqtt_ip}",
      "-v ${datadir}/mqtt_data:/mosquitto/data",
      "-v ${datadir}/mqtt_config:/mosquitto/config",
    ],
    cmd     => 'mosquitto -c /mosquitto-no-auth.conf',
    require => [File["${datadir}/mqtt_config"], File["${datadir}/mqtt_data"]],
  }

  docker::container { 'teslamate':
    image => 'teslamate/teslamate:latest',
    args  => [
      "--ip ${teslamate_ip}",
      "-e ENCRYPTION_KEY=${encryption_key}",
      '-e DATABASE_USER=teslamate',
      "-e DATABASE_PASS=${database_password}",
      '-e DATABASE_NAME=teslamate',
      "-e DATABASE_HOST=${postgres_ip}",
      "-e MQTT_HOST=${mqtt_ip}",
    ],
    cmd   => '',
  }

  file { '/usr/local/bin/teslamate-backup.sh':
    ensure => file,
    source => 'puppet:///modules/teslamate/teslamate-backup.sh',
    mode   => '0755',
  }

  file { '/etc/systemd/system/teslamate-backup.service':
    ensure  => file,
    content => template('teslamate/teslamate-backup.service.erb'),
    notify  => Service['teslamate-backup.timer'],
  }

  file { '/etc/systemd/system/teslamate-backup.timer':
    ensure => file,
    source => 'puppet:///modules/teslamate/teslamate-backup.timer',
    notify => Service['teslamate-backup.timer'],
  }

  service { 'teslamate-backup.timer':
    ensure => running,
    enable => true,
  }

  tidy { "${datadir}/backup":
    age     => '30d',
    recurse => true,
    matches => 'dump_.*',
  }

  if $backup_target != '' {
    backup::repo { 'teslamate':
      source        => "${datadir}/backup",
      target        => $backup_target,
      watchdog_url  => $backup_watchdog,
      password      => $backup_password,
      environment   => $backup_environment,
      rclone_config => $backup_rclone,
    }
  }
}
