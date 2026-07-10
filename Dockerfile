FROM pandoc/core:latest

WORKDIR /input

# Mermaid CLI requires Node.js and Chromium.
# Chromium is installed in the image, so Puppeteer download is skipped.
ENV PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN apk add --no-cache \
      nodejs \
      npm \
      chromium \
      nss \
      freetype \
      harfbuzz \
      ca-certificates \
      ttf-freefont \
      font-noto \
      font-noto-cjk \
      python3 \
    && npm install -g @mermaid-js/mermaid-cli

COPY scripts/md2docx.sh /usr/local/bin/md2docx.sh
COPY scripts/format_docx_tables.py /usr/local/bin/format_docx_tables.py
RUN chmod +x /usr/local/bin/md2docx.sh

ENTRYPOINT ["/usr/local/bin/md2docx.sh"]
