# Build stage: copy the Godot web export output
# Run: Project > Export > Web in Godot, export to ./web_export/
FROM nginx:stable-alpine

# Copy the nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the exported game files
COPY web_export/ /usr/share/nginx/html/

EXPOSE 80
