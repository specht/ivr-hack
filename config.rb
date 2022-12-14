#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'yaml'

PROFILE = [:static, :dynamic]

# This runs in development mode by default. To switch to production,
# place a file called deployment.production in this directory.

DEVELOPMENT = !(ENV['QTS_DEVELOPMENT'].nil?)
PROJECT_NAME = 'ivrhack' + (DEVELOPMENT ? 'dev' : '')
DEV_NGINX_PORT = 8025
DEV_PHPMYADMIN_PORT = 8026
DEV_NEO4J_PORT = 8021
LOGS_PATH = DEVELOPMENT ? './logs' : "/home/qts/logs/#{PROJECT_NAME}"
DATA_PATH = DEVELOPMENT ? './data' : "/home/qts/data/#{PROJECT_NAME}"
NEO4J_DATA_PATH = File::join(DATA_PATH, 'neo4j')
NEO4J_LOGS_PATH = File::join(LOGS_PATH, 'neo4j')
MYSQL_DATA_PATH = File::join(DATA_PATH, 'mysql')
RAW_FILES_PATH = File::join(DATA_PATH, 'raw')
GEN_FILES_PATH = File::join(DATA_PATH, 'gen')
WEBSITE_HOST = 'ivr.hackschule.de'
LETSENCRYPT_EMAIL = 'specht@gymnasiumsteglitz.de'

docker_compose = {
    :version => '3',
    :services => {},
}

if PROFILE.include?(:static)
    docker_compose[:services][:nginx] = {
        :build => './docker/nginx',
        :volumes => [
            './src/static:/usr/share/nginx/html:ro',
            "#{RAW_FILES_PATH}:/raw:ro",
            "#{GEN_FILES_PATH}:/gen:ro",
            "#{LOGS_PATH}:/var/log/nginx",
        ]
    }
    if !DEVELOPMENT
        docker_compose[:services][:nginx][:environment] = {
            "VIRTUAL_HOST" => "#{WEBSITE_HOST}",
            "LETSENCRYPT_HOST" => "#{WEBSITE_HOST}",
            "LETSENCRYPT_EMAIL" => "#{LETSENCRYPT_EMAIL}"
        }
        docker_compose[:services][:nginx][:expose] = ['80']
    end
    if PROFILE.include?(:dynamic)
        docker_compose[:services][:nginx][:links] = ["ruby:ruby"]
    end
    nginx_config = <<~eos
        log_format custom '$http_x_forwarded_for - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$request_time"';

        server {
            listen 80;
            server_name localhost;
            client_max_body_size 8M;

            access_log /var/log/nginx/access.log custom;

            charset utf-8;

            location /raw/ {
                rewrite ^/raw(.*)$ $1 break;
                root /raw;
            }

            location /gen/ {
                rewrite ^/gen(.*)$ $1 break;
                root /gen;
            }

            location / {
                root /usr/share/nginx/html;
                include /etc/nginx/mime.types;
                try_files $uri @ruby;
            }

            location @ruby {
                proxy_pass http://ruby:9292;
                proxy_set_header Host $host;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection Upgrade;
            }
        }

    eos
    File::open('docker/nginx/default.conf', 'w') do |f|
        f.write nginx_config
    end
    if PROFILE.include?(:dynamic)
        docker_compose[:services][:nginx][:depends_on] = [:ruby]
    end
end

if PROFILE.include?(:dynamic)
    env = {}
    env['DEVELOPMENT'] = 1 if DEVELOPMENT
    docker_compose[:services][:ruby] = {
        :build => './docker/ruby',
        :volumes => ['./src/ruby:/app:ro',
                     "#{RAW_FILES_PATH}:/raw",
                     "#{GEN_FILES_PATH}:/gen"],
        :environment => env,
        :privileged => true,
        :working_dir => '/app',
        :entrypoint =>  DEVELOPMENT ?
            'rerun -b --dir /app -s SIGKILL \'rackup --host 0.0.0.0\'' :
            'rackup --host 0.0.0.0'
    }
    if PROFILE.include?(:neo4j)
        docker_compose[:services][:ruby][:depends_on] ||= []
        docker_compose[:services][:ruby][:depends_on] << :neo4j
        docker_compose[:services][:ruby][:links] ||= []
        docker_compose[:services][:ruby][:links] << 'neo4j:neo4j'
    end
end

if PROFILE.include?(:neo4j)
    docker_compose[:services][:neo4j] = {
        :build => './docker/neo4j',
        :volumes => ["#{NEO4J_DATA_PATH}:/data",
                     "#{NEO4J_LOGS_PATH}:/logs"]
    }
    docker_compose[:services][:neo4j][:environment] = {
        'NEO4J_AUTH' => 'none',
        'NEO4J_dbms_logs__timezone' => 'SYSTEM',
        #'NEO4J_dbms_allow__upgrade' => 'true',
    }
    docker_compose[:services][:neo4j][:user] = "#{UID}"
end

if PROFILE.include?(:mysql)
    docker_compose[:services][:mysql] = {
        :image => 'mysql/mysql-server',
        :command => ["--default-authentication-plugin=mysql_native_password"],
        :volumes => ["#{MYSQL_DATA_PATH}:/var/lib/mysql"],
        :restart => 'always',
        :environment => {
            'MYSQL_ROOT_HOST' => '%',
            'MYSQL_ROOT_PASSWORD' => MYSQL_ROOT_PASSWORD
        }
    }
    docker_compose[:services][:phpmyadmin] = {
        :image => 'phpmyadmin/phpmyadmin',
        :volumes => ["#{MYSQL_DATA_PATH}:/var/lib/mysql"],
        :restart => 'always',
        :expose => ['80']
    }
    docker_compose[:services][:phpmyadmin][:depends_on] ||= []
    docker_compose[:services][:phpmyadmin][:depends_on] << :mysql
    docker_compose[:services][:phpmyadmin][:links] = ['mysql:mysql']
    docker_compose[:services][:phpmyadmin][:environment] = {
        'PMA_HOST' => 'mysql',
        "VIRTUAL_HOST" => "phpmyadmin.#{WEBSITE_HOST}",
        "LETSENCRYPT_HOST" => "phpmyadmin.#{WEBSITE_HOST}",
        "LETSENCRYPT_EMAIL" => "#{LETSENCRYPT_EMAIL}"
    }
    docker_compose[:services][:neo4j][:user] = "#{UID}"
end

docker_compose[:services].values.each do |x|
    x[:network_mode] = 'default'
    # x[:networks] = ['hackschule']
end

if DEVELOPMENT
    docker_compose[:services][:nginx][:ports] = ["127.0.0.1:#{DEV_NGINX_PORT}:80"]
    # docker_compose[:services][:phpmyadmin][:ports] = ["127.0.0.1:#{DEV_PHPMYADMIN_PORT}:80"]
    if PROFILE.include?(:neo4j)
        docker_compose[:services][:neo4j][:ports] = ["127.0.0.1:#{DEV_NEO4J_PORT}:7474",
                                                     "127.0.0.1:7687:7687"]
    end
else
    docker_compose[:services].values.each do |x|
        x[:restart] = :always
    end
end

# docker_compose[:networks] = {:hackschule => {:driver => 'bridge'}}

docker_compose[:services].keys.each do |service|
    e = docker_compose[:services][service][:environment] || {}
    e = e.to_json
    docker_compose[:services][service][:environment] = JSON.parse(e)
    docker_compose[:services][service][:environment]["HACKSCHULE_SERVICE"] = "#{service}"
end

File::open('docker-compose.yaml', 'w') do |f|
    f.puts "# NOTICE: don't edit this file directly, use config.rb instead!\n"
    f.write(JSON::parse(docker_compose.to_json).to_yaml)
end

FileUtils::mkpath(LOGS_PATH)
if PROFILE.include?(:dynamic)
    FileUtils::cp('src/ruby/Gemfile', 'docker/ruby/')
    FileUtils::mkpath(RAW_FILES_PATH)
    FileUtils::mkpath(GEN_FILES_PATH)
end
if PROFILE.include?(:neo4j)
    FileUtils::mkpath(NEO4J_DATA_PATH)
    FileUtils::mkpath(NEO4J_LOGS_PATH)
end

system("docker-compose --project-name #{PROJECT_NAME} #{ARGV.join(' ')}")
