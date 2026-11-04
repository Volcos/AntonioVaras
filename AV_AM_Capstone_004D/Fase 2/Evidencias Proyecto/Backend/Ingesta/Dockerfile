FROM mcr.microsoft.com/playwright:v1.62.1-noble
# Instalar Xvfb para emular un monitor en la memoria RAM
RUN apt-get update && apt-get install -y \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar archivos de dependencias e instalar
COPY package*.json ./
RUN npm ci

# Copiar el resto del código
COPY . .

# Iniciar la aplicación envolviendo la ejecución en la pantalla virtual
CMD ["xvfb-run", "--auto-servernum", "--server-args=-screen 0 1280x1024x24", "node", "index.js"]