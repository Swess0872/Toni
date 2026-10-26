# Serves the Flutter web build. Build it first (CI does this):
#   flutter build web --release
#   docker build -t toni-web app
FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html
EXPOSE 8080
