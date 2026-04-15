FROM wordpress:latest

# On installe les dépendances nécessaires à WP-CLI et à l'extraction
RUN apt-get update && apt-get install -y sudo less mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Téléchargement et installation de WP-CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# On s'assure que l'image utilise bien le script de démarrage officiel
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]