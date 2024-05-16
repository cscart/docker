#!/bin/bash

. .env

if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

if ! $(docker compose &>/dev/null) && [ $? -eq 0 ]; then
  echo 'Error: docker compose plugin is not installed.'
  exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
  echo 'Error: curl is not installed.' >&2
  exit 1
fi

domains=($CSCART_ADDRESS)
rsa_key_size=4096
data_path="$CERTBOT_DATA"
email="$CERTBOT_EMAIL" # Adding a valid address is strongly recommended
staging="$CERTBOT_STAGING_MODE" # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi


if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker compose -f docker-compose.yaml run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 365\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker compose -f docker-compose.yaml up --force-recreate -d nginx
echo

docker exec -ti nginx /bin/bash -c "envsubst '\${CSCART_ADDRESS}' < /etc/nginx/templates/cscart.dist > /etc/nginx/conf.d/cscart.conf"
docker exec -ti nginx /bin/bash -c "mv /etc/nginx/templates/* /etc/nginx/conf.d/ && rm /etc/nginx/conf.d/cscart.dist"
docker exec -ti nginx nginx -s reload
docker exec -ti php /bin/bash -c "mv /usr/local/etc/php/conf.d.example/* /usr/local/etc/php/conf.d/"

echo "### Deleting dummy certificate for $domains ..."
docker compose -f docker-compose.yaml run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo

echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker compose -f docker-compose.yaml run --rm --entrypoint "\
certbot certonly --webroot -w /var/www/certbot \
  $staging_arg \
  $email_arg \
  --agree-tos \
  --no-eff-email \
  --rsa-key-size $rsa_key_size \
  --force-renewal \
  $domain_args" certbot
echo

echo "### Start infra and reloading nginx ..."

docker compose -f docker-compose.yaml up -d
docker compose -f docker-compose.yaml exec nginx nginx -s reload
