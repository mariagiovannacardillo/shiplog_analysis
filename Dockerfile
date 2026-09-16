# Usa un'immagine Python ufficiale e leggera
FROM python:3.10-slim

# Imposta la cartella di lavoro dentro il container
WORKDIR /app

# Copia solo il file dei requirements e installa le dipendenze
# Questo sfrutta la cache di Docker per essere più veloce
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia il resto dei file necessari (lo script e il DB)
COPY extract_data.py .
COPY shiplog.db .

# Esegue lo script Python all'avvio
CMD ["python", "extract_data.py"]
