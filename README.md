# MaxMind GeoIP DB updater

[![License: EUPL 1.2](https://raw.githubusercontent.com/eClip-/EUPL-badge/master/eupl_1.2.svg)](https://www.gnu.org/licenses/gpl-3.0)

Bash script with minimal dependencies to update MaxMind's GeoIP databases. 

Features :

- download only if there is a new release of GeoIP databases.
- minimal dependencies

## Requirements

- curl
- awk, sed, grep, md5sum, gzip

Ubuntu / Debian : ```apt install coreutils curl gawk grep gzip sed```

## Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md)

## Configuration & Usage

### Config via Environment variables

**override ALL** other configurations even given in configuration file

Configuration file : 

- MAXMIND_CONFIG_FILE        : MaxMind's `geoipupdate` [config file format](https://github.com/maxmind/geoipupdate/blob/main/conf/GeoIP.conf.default).

AccountID :

1. MAXMIND_ACCOUNT_ID         : Your MaxMind AccountID
2. MAXMIND_ACCOUNT_ID_FILE    : filename path to your AccountID (first line)

License key : 

1. MAXMIND_LICENSE_KEY        : Your license key string
1. MAXMIND_LICENSE_KEY_FILE   : filename path to the license key string (first line)

Database location :

- MAXMIND_DATADIR            : path to the DB directory ; default to this script directory)
  Default value : ```<script directory/```<br>

Database editions :
- MAXMIND_EDITIONS           : list of editions you want to update.<br>
  Default value :<br>
  ```MAXMIND_EDITIONS=('GeoLite2-ASN' 'GeoLite2-City' 'GeoLite2-Country')```

Other : 
- VERBOSE                    : active verbosity

### Config via GeoIP.conf formatted file

Use a MaxMind's `geoipupdate` [config file format](https://github.com/maxmind/geoipupdate/blob/main/conf/GeoIP.conf.default).

By default : Try to use /etc/GeoIP.conf 

- Autodetect AccountID
- Autodetect License key
- Autodetect EditionIDs

### Usages

#### With env variables only

```bash
$ MAXMIND_LICENSE_KEY="TOTOISWITHYOU" MAXMIND_ACCOUNT_ID="123123" DRYRUN=1 VERBOSE=1 ./update-maxmind-geoip.sh
Updating MaxMind GeoIP DBs : 
    - Try config file          : /etc/GeoIP.conf
    - Editions                 : GeoLite2-ASN GeoLite2-City GeoLite2-Country
    - Destination              : /home/me/update-maxmind-geoip
    - AccountID                : 123123
    - License Key              : TOTOISWITHYOU
DRYRUN is defined or not equal to 0. Exiting
```

#### using configuration file and explicit destination directory

```bash
$ DRYRUN=1 VERBOSE=1 ./update-maxmind-geoip.sh /tmp/GeoIP.conf /tmp
Updating MaxMind GeoIP DBs : 
    - Try config file          : /tmp/GeoIP.conf
    - Editions                 : GeoLite2-ASN GeoLite2-City GeoLite2-Country
    - Destination              : /tmp
    - AccountID                : 123123
    - License Key              : TOTOISWITHYOU
DRYRUN is defined or not equal to 0. Exiting
```

### Cron example

#### With config file
`/etc/cron.d/maxmind-autoupdate`
```bash 
MAILTO=your@email
# m h  dom mon dow  user   command
0   6  *   *   *    root   /usr/local/sbin/update-maxmind-geoip.sh /etc/GeoIP.conf /usr/share/

```
#### With Env vars

`/etc/cron.d/maxmind-autoupdate`
```bash 
MAILTO=your@email
MAXMIND_LICENSE_KEY="TOTOISWITHYOU"
MAXMIND_ACCOUNT_ID="123123"
# m h  dom mon dow  user   command
0   6  *   *   *    root   /path/to/update-maxmind-geoip/update-maxmind-geoip.sh
```
results : all DBs will be in `/path/to/update-maxmind-geoip/`

on RedHat and Archlinux : you must export vars in the same line like : 
```
0   6  *   *   *    root   export MAXMIND_LICENSE_KEY="TOTOISWITHYOU"; /path/to/update-maxmind-geoip/update-maxmind-geoip.sh
```

## License

