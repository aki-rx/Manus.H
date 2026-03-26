FROM ghcr.io/open-webui/open-webui:latest

# Copy custom CSS theme (JetBrains Mono + yellowish accent + faded params)
COPY custom.css /app/build/static/custom.css

# Copy the model parameter fader JS
COPY scripts/model_param_fader.js /app/build/static/model_param_fader.js

# Inject the custom CSS and JS into the main HTML page
# This appends a <link> for the CSS and a <script> for the JS before </head>
RUN sed -i 's|</head>|<link rel="stylesheet" href="/static/custom.css" />\n<script src="/static/model_param_fader.js" defer></script>\n</head>|' /app/build/index.html

# Copy custom favicon if provided
# COPY assets/favicon.svg /app/build/static/favicon.svg
# COPY assets/favicon.png /app/build/static/favicon.png
