# Static file server for EpicBook's /assets (CSS, JS, images)
FROM nginx:alpine
# Remove the default Nginx welcome page
RUN rm -rf /usr/share/nginx/html/*
# Copy the static files into the Nginx web root
COPY public/ /usr/share/nginx/html/
EXPOSE 80
# nginx:alpine's default CMD starts Nginx in the foreground
