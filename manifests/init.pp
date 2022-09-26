# @summary Configure TeslaMate instance
#
# @param datadir handles storage of Postgres and MQTT data
# @param database_password sets the postgres password for teslamate
# @param encryption_key sets the key used to encrypt tesla API tokens
# @param teslamate_ip sets the IP of the teslamate container
# @param postgres_ip sets the IP of the postgres container
# @param mqtt_ip sets the IP of the mqtt container
class teslamate (
  String $datadir,
  String $database_password,
  String $encryption_key,
  String $teslamate_ip = '172.17.0.2',
  String $postgres_ip = '172.17.0.3',
  String $mqtt_ip = '172.17.0.4',
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

  file { [$datadir, "${datadir}/postgres", "${datadir}/mqtt_config", "${datadir}/mqtt_data"]:
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
    cmd     => '',
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
}
