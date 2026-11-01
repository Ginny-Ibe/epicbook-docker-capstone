# Static file server for EpicBook's /assets (CSS, JS, images)
# Hardened: non-root Nginx (runs as 'nginx', listens on 8080)
FROM nginxinc/nginx-unprivileged:alpine
# Root only long enough to clear the default web root
USER root
RUN rm -rf /usr/share/nginx/html/*
# Copy the static files into the Nginx web root
COPY public/ /usr/share/nginx/html/
# Drop to the unprivileged user for runtime
USER nginx
EXPOSE 8080
