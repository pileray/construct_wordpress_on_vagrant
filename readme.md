# Vagrant上にWordpress環境を構築する

## 要件
- vagrantでcentos7を立ち上げる
- centos7で管理用ユーザーを作成
- ローカルからvagrantへsshで管理ユーザーにログインする
- nginx, php-fpm7.4, MySQL8で構築する
- dev.menta.meで名前解決してアクセスできるようにする
- MySQLのバックアップシェルスクリプトを作成する

## テスト証跡
### mentaユーザーでのssh接続
```
fukuiryousukenoMacBook-Pro:~ fukuiryousuke$ ssh menta@192.168.56.15 -i ~/.ssh/menta
Last login: Tue Mar  8 11:50:49 2022
[menta@dev ~]$
```

### dev.menta.meでの名前解決
```
fukuiryousukenoMacBook-Pro:~ fukuiryousuke$ ping dev.menta.me
PING dev.menta.me (192.168.56.15): 56 data bytes
64 bytes from 192.168.56.15: icmp_seq=0 ttl=64 time=0.335 ms
64 bytes from 192.168.56.15: icmp_seq=1 ttl=64 time=0.449 ms
64 bytes from 192.168.56.15: icmp_seq=2 ttl=64 time=0.634 ms
64 bytes from 192.168.56.15: icmp_seq=3 ttl=64 time=0.361 ms
ex64 bytes from 192.168.56.15: icmp_seq=4 ttl=64 time=0.414 ms
64 bytes from 192.168.56.15: icmp_seq=5 ttl=64 time=0.402 ms
^C
--- dev.menta.me ping statistics ---
6 packets transmitted, 6 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 0.335/0.433/0.634/0.097 ms
```
<img width="1140" alt="218894d086de5f583255eaca62ce9bfc" src="https://user-images.githubusercontent.com/60649665/157239854-2dc1520f-a2cb-4863-9838-bd3c6e0471a1.png">

### MySQLバックアップシェルスクリプト
```
[menta@dev ~]$ sudo su -
Last login: 火  3月  8 11:52:14 UTC 2022 on pts/0
[root@dev ~]# sh mysqlbackup.sh
[root@dev ~]# cd ~/backup/mysql/
[root@dev mysql]# sudo ls -la *.sql
-rw-r--r--. 1 root root 203 Mar  7 11:56 20220307.sql
-rw-r--r--. 1 root root 203 Mar  8 12:39 20220308.sql
```

---
## Vagrant環境構築

```
# 任意の作業ディレクトリを作成し移動
$ vagrant box add centos/7
$ vagrant init

# Vagrantfileの編集
$ vi Vagrantfile
config.vm.box = "centos/7"

# vagrant立ち上げ
$ vagrant up

# vagrantにssh接続
$ vagrant ssh

# vagrant内のパッケージアップデートしログアウト
$ sudo yum update -y
$ exit

# 共有フォルダ用プラグインインストール
$ vagrant plugin install vagrant-vbguest

# 再びVagrantfileを編集
# ホストマシンから接続できる静的アドレスを設定
# Vagrantfile内で以下を追加（コメントアウトされているので解除）
config.vm.network "private_network", ip: "192.168.56.15"

# 共有フォルダ設定
config.vm.synced_folder "~/git/MENTA/script", "~/local-directory/script", owner: 'vagrant', group: 'vagrant'

$ vagrant reload
```


## ユーザー追加

```
$ vagrant ssh

# rootユーザーでログイン
$ su

# ユーザー追加
$ useradd menta
$ passwd menta

# sudo権限を付与するためwheelグループへ追加
$ gpasswd -a menta wheel
```


## SSHキーペア設定

```
# ホスト側
$ cd ~/.ssh/
$ ssh-keygen -t rsa #鍵生成
$ cat menta.pub | pbcopy #公開鍵をコピー

# ゲスト側
# 作成したユーザーでログイン
$ su menta

# 公開鍵の設定
$ mkdir ~/.ssh
$ chmod 700 .ssh #ディレクトリの権限変更
$ vi .ssh/authorized_keys #公開鍵をペースト
$ chmod 600 .ssh/authorized_keys #公開鍵の権限変更

# ホスト側からssh接続
$ ssh -i ~/.ssh/menta menta@192.168.56.15
```


## nginxのインストール

```
# 公式サイト http://nginx.org/en/linux_packages.htmlに沿ってインストール
$ sudo yum install yum-utils
$ sudo vi /etc/yum.repos.d/nginx.repo #以下を記載

[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

$ sudo yum install nginx
```


## nginxの起動

```
$ sudo systemctl start nginx
$ sudo systemctl enable nginx #再起動時の自動起動設定
$ sudo systemctl status nginx
Active: active (running)

# http://192.168.56.15/ で「Welcome to nginx!」ならOK
```


## php-fpm7.4のインストール

```
# php-fpmとはPHPを実行するためのCGI
# こちらが参考になる
# https://qiita.com/kotarella1110/items/634f6fafeb33ae0f51dc

# yum標準のリポジトリではインストールできないため、EPELリポジトリとremiリポジトリの追加
$ sudo yum -y install epel-release
$ sudo rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

$ sudo yum -y install --enablerepo=epel,remi,remi-php74  php php-mbstring php-pdo php-mysqlnd php-fpm
```


## Nginxの設定

```
# メイン設定ファイルを以下のように設定
$ vi /etc/nginx/conf.d/default.conf

server {
    listen       80;
    server_name  dev.menta.me;
    root /var/www/html/;
    charset UTF-8;
    access_log  /var/log/nginx/dev.menta.me.access.log  main;
    error_log /var/log/nginx/dev.menta.me.error.log;

    location / {
        index  index.php index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    location ~ \.php$ {
        fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }
}

# 分かりやすいようにファイル名を適宜変更
$ mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/dev.menta.me.conf

# Nginxを再起動
$ sudo systemctl restart nginx
```


## php-fpmの設定

```
# 設定ファイルを以下のように設定
$ sudo vi /etc/php-fpm.d/www.conf

listen = /var/run/php-fpm/php-fpm.sock
user = nginx 
group = nginx
listen.owner = nginx #コメントアウトを外す
listen.group = nginx #コメントアウトを外す

# php-fpmの起動
$ systemctl start php-fpm 
$ sudo systemctl enable php-fpm #再起動時の自動起動設定
```


## PHPの動作確認

```
$ sudo vi /var/www/html/index.php

<?php
 echo "Hello World!";
?>

# http://192.168.56.15/ で「Hello World!」が表示されればOK!

$ sudo rm /var/www/html/index.php
```


## WordPressのインストール

```
# Nginxのドキュメントルートディレクトリへ移動
$ cd /var/www/html/

$ sudo yum -y install wget
$ sudo wget https://ja.wordpress.org/latest-ja.tar.gz
$ tar xfz latest-ja.tar.gz
$ sudo chown -R nginx. wordpress/ #所有権をnginxユーザーとグループに変更

# http://192.168.56.15/wordpress/　で管理画面が表示されればOK!

# ドキュメントルートの変更
$ sudo mv wordpress/ ../dev.menta.me/
$ sudo vi /etc/nginx/conf.d/dev.menta.me.conf #以下の通りrootを変更

server {
    root /var/www/dev.menta.me;
（後略・・・）

$ sudo systemctl restart nginx
```


## MySQLのインストール

```
# MariaDBのアンインストール
$ sudo yum list installed | grep maria #MariaDBがインストールされているか確認
$ sudo yum remove mariadb-libs #アンインストール
$ sudo rm -rf /var/lib/mysql/ #関連ライブラリがあれば

# MySQLリポジトリの追加
# https://dev.mysql.com/downloads/repo/yum/　よりLinuxのバージョンに沿ったリポジトリのURLをコピー
$ sudo yum install https://dev.mysql.com/get/mysql80-community-release-el7-5.noarch.rpm

# MySQLのインストール
$ sudo yum install mysql-community-server

# 起動
$ sudo systemctl start mysqld.service
$ sudo systemctl enable mysqld.service
```


## MySQLの設定

```
# インストール直後は初期パスワードがログに出力されているため確認
$ sudo cat /var/log/mysqld.log | grep password

# 初期設定を行う
$ mysql_secure_installation
（全てyで実行）
All Done!

# rootユーザーでログイン
$ mysql -u root -p

# wordpress用ユーザーの作成
mysql> CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'パスワード';

# wordpress用データベースの作成
mysql> CREATE DATABASE wordpress_db;

# wordpress用ユーザーへDBへの権限を付与
muysql> GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wordpress'@'localhost';

# 権限設定をリフレッシュ
mysql> FLUSH PRIVILEGES;
```


## WordPrssのデータベース接続

```
# http://192.168.56.15/へアクセスし、上記工程で作成したデータベース・ユーザー・パスワードを入力し接続設定を行う。
```


## 名前解決の設定

```
# ホストマシンのブラウザから名前解決を行ってVagrant上のサーバーにアクセスするにはホストマシンの/etc/hostsの設定を変更する必要がある。
# ホストマシンの/etc/hostsに以下を追加。

$ vi /etc/hosts
192.165.56.15 dev.menta.me

```


## php-fpmのチューニング

```
$ htop #メモリの空き状況を確認

# 空き状況を確認しながらphp-fpmの設定ファイルを変更
$ sudo vi /etc/php-fpm.d/www.conf

pm = static
pm.max_children = 25
pm.start_servers = 25
pm.min_spare_servers = 25
pm.max_spare_servers = 25
pm.process_idle_timeout = 10s;
pm.max_requests = 50
request_terminate_timeout = 60
php_admin_value[memory_limit] = 128M

# 再起動
$ sudo systemctl restart php-fpm
```

## MySQLバックアップ用のシェルスクリプト作成
```
$ sudo su -
$ cd ~
$ mkdir ~/backup/mysql/
$ vi mysqlbackup.sh #以下の通りシェルスクリプトを作成

#! /bin/bash
source ~/secrets.sh

period=5 #保存期間
dirpath="/root/backup/mysql" #保存先ディレクトリ
filename=`date '+%Y%m%d'` #ファイル名（今回はyyyymmddで指定）
mysqldump -u root -p $password --lock-all-tables --all-databases --events > $dirpath/$filename.sql #xxxxにMySQLのrootパスワードを入れる
oldfile=`date --date "$period days ago" '+%Y%m%d'`
rm -f $dirpath/$oldfile.sql #保存期間を過ぎたファイルを削除

$ chmod 700 mysqlbackup.sh

# パスワードファイルを以下の書式で作成
$ vi secrets.sh
#! /bin/bash
password="hogehoge"

# 権限をrootに絞る
$ chmod 700 secrets.sh

# 日次でcronの設定（毎日0時とする）
$ sudo crontab -u root -e

0 0 * * * sh ~/mysqlbackup.sh

```
