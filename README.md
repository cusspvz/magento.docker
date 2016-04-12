# cusspvz/magento

[**@GitHub** ](https://github.com/cusspvz/magento.docker)
[**@Docker Hub**](https://hub.docker.com/cusspvz/magento)

a scalable Magento 2.0 image based on Alpine, PHP-FPM, NginX and MariaDB Galera Cluster

![magento-docker](http://magenticians.com/wp-content/uploads/2014/12/docker-magento-2-768x250.png)

## Launching

### Ephemeral data

```bash
docker run -ti -p 80:80 cusspvz/magento
```

### Persistent data

```bash
docker run -ti cusspvz/magento
```

**NOTE:** I've used volume names instead of absolute paths, but please change
accordingly with your needs.

### Clustered data

WHAAAT????

Yes, this image is scalable. You just need to pass down how can it reach other
nodes and it will scale MariaDB.

```bash
docker run -ti --name magento1 cusspvz/magento
docker run -ti --name magento2 -l magento1:magento1 -e NODES=magento1 cusspvz/magento
docker run -ti --name magento3 -l magento1:magento1 -e NODES=magento1 cusspvz/magento
```


## Environment Variables

### Clustering configuration

#### `NODES`
Defaults to ` ` (Empty string)

This variable will allow this container to scale among other nodes and share
the same data (from database and other assets)

You just need to pass down a list delimited by a comma (`node1,node2,node3...`)
and it will automatically configure and scale.

**NOTE:** This only needs one active host, it will actually discover the other
ones automatically. In case you use [rancher] or other orchestration tool that
provides a DNS for all the nodes, you could simply pass it instead.

**WARNING:** Clustering will be disabled in case you decide to use an external
database, meaning you will be responsable for handling all the data, including
the shared media resources such as product images.

### Mysql configuration

#### `MYSQL_HOST`
Defaults to `localhost`

> If this value is different than `localhost`, internal mysql server WON'T be initialized! Do this only in case you want to take care of data and scaling
manually.

#### `MYSQL_PORT`
Defaults to `3306`

#### `MYSQL_DATABASE`
Defaults to `magento`


#### `MYSQL_USER`
Defaults to `root`


#### `MYSQL_PASSWORD`
Defaults to `ThisShouldBeChangableLater`

nice password, hehehe



## Roadmap / TODO

- Check benefits of including APC on the stack
- Add support for Redis clustering once sharding is automatic
- Add support for external Redis server



## Contributing

### Building the image
```bash
docker build -t magento .
docker run -ti -p 80:80 magento
```

### Watch files and build

```bash
inotifywait -mr --timefmt '%d/%m/%y %H:%M' --format '%T %w %f' \
-e close_write $(pwd) | \
while read date time dir file; do
  docker build -t magento .

  docker kill magento
  docker rm magento
  docker run -ti \
    --name magento \
    -v magento_settings:/magento/app/etc
    -v magento_data:/magento/pub
    -v magento_mysql_data:/var/lib/mysql
    -p 80:80 \
    magento &
done
```



## FAQ

### Another magento image?

There are a few images that covers Magento 2, fewer on MariaDB and even fewer on Alpine.

The main purpose of this image is to deliver a **ready to use** image, just
launch it and you're ready to go!

### Wait, but what if I want my own MariaDB/MySQL to be a separated container?

Just launch your container with a different `MYSQL_HOST`.


###### Example
```bash
docker run -d --name=magento-mysql mysql;
docker run -d --name=magento \
    -e MYSQL_HOST=mysql-server
    -l magento-mysql:mysql-server \
    cusspvz/magento;
```


### Why you did choose such stack?

Well, who doesn't want a Magento container to spend only about ~350MB of RAM?
If you launch this stack separately you will face an ~1.8GB of RAM footprint.

Seems legit?

Then, while building it I've decided it should be completely scalable, so there it is.


### You're god!!

Amén!

Just kidding, I'm not but if you really enjoyed this please spread the word.
Show your love by sharing on Twitter and giving a star to this repo!



## Licensing
GPL 3.0



## Copyright
2016 - 'til Infinity
Brought to you with <3 by [José Moreira](https://twitter.com/cusspvz)
