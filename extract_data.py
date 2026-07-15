import sqlite3
import pandas as pd
import numpy as np

def main():
    print("[INFO] Connessione a shiplog.db per estrazione dataset Dashboard...")
    conn = sqlite3.connect('shiplog.db')

    # Unisco le tabelle per fornire a Power BI tutti i dati in un unico foglio
    # Aggiungo car.mode as carrier_mode per poter fare il check 
    # di Data Quality sui costi (esattamente come nella query SQL)
    query = """
    SELECT 
        s.shipment_id, s.booking_date, s.departure_date, s.arrival_date, 
        s.weight_kg, s.volume_cbm, s.freight_cost_eur, s.status, s.origin_country, s.destination_country,
        c.customer_name, c.customer_segment,
        car.carrier_name, s.mode, car.mode AS carrier_mode
    FROM shipments s
    LEFT JOIN customers c ON s.customer_id = c.customer_id
    LEFT JOIN carriers car ON s.carrier_id = car.carrier_id
    """
    
    df = pd.read_sql_query(query, conn)
    
    print("[INFO] Applicazione calcoli DAX e trasformazioni in Python...")
    
    # ---------------------------------------------------------
    # 1. PARSING DELLE DATE E CAMPI TEMPORALI (Per Query 4.3 e 4.4)
    # ---------------------------------------------------------
    df['booking_date'] = pd.to_datetime(df['booking_date'])
    df['departure_date'] = pd.to_datetime(df['departure_date'])
    df['arrival_date'] = pd.to_datetime(df['arrival_date'])
    
    # Creo la colonna Anno-Settimana (Es: 2024-42) per il grafico dei trend di insuccesso
    df['Anno_Settimana'] = df['booking_date'].dt.strftime('%Y-%W').fillna('N/D')

    # Calcolo i giorni netti di transito
    df['Giorni_Transito'] = (df['arrival_date'] - df['departure_date']).dt.days

    # ---------------------------------------------------------
    # 2. SLA TEORICO (Per Query 4.4: On-Time Delivery Rate)
    # ---------------------------------------------------------
    condizioni_sla = [
        (df['status'] == 'Delivered') & (df['mode'] == 'Air') & (df['Giorni_Transito'] <= 7),
        (df['status'] == 'Delivered') & (df['mode'] == 'Road') & (df['Giorni_Transito'] <= 14),
        (df['status'] == 'Delivered') & (df['mode'] == 'Sea') & (df['Giorni_Transito'] <= 45)
    ]
    # Assegno 1 se in SLA, 0 se in ritardo. Se non è Delivered, metto NaN per escluderlo.
    df['SLA_Rispettato'] = np.select(condizioni_sla, [1, 1, 1], default=0)
    df.loc[df['status'] != 'Delivered', 'SLA_Rispettato'] = np.nan

    # ---------------------------------------------------------
    # 3. ANALISI COSTI UNITARI GIUSTA (Filtro Qualità Applicato)
    # ---------------------------------------------------------
    # Verifico che la modalità coincida, altrimenti non calcolo il costo
    is_mode_aligned = df['mode'] == df['carrier_mode']
    
    # Calcolo i costi sostituendo gli zeri con NaN per evitare l'errore di divisione (equivalente a NULLIF)
    df['Costo_per_Kg'] = np.where(is_mode_aligned, df['freight_cost_eur'] / df['weight_kg'].replace(0, np.nan), np.nan)
    df['Costo_per_CBM'] = np.where(is_mode_aligned, df['freight_cost_eur'] / df['volume_cbm'].replace(0, np.nan), np.nan)

    # ---------------------------------------------------------
    # 4. MASTER VIEW (Per Query 19)
    # ---------------------------------------------------------
    # Ricreo le stesse 7 casistiche della UNION ALL
    condizioni_errore = [
        (df['weight_kg'] <= 0) | (df['volume_cbm'] <= 0) | (df['freight_cost_eur'] <= 0),
        (df['carrier_name'].isna()),
        (df['customer_name'].isna()),
        (df['departure_date'] < df['booking_date']),
        (df['arrival_date'] < df['departure_date']),
        (df['status'] == 'Delivered') & (df['arrival_date'].isna() | df['origin_country'].isna() | df['destination_country'].isna()),
        (df['status'] == 'Cancelled') & df['arrival_date'].notna()
    ]
    
    scelte_errore = [
        "Valori Negativi o Zero", 
        "Anagrafica Carrier Mancante",
        "Anagrafica Customer Mancante",
        "Partenza precede Prenotazione",
        "Arrivo precede Partenza",
        "Delivered senza info essenziali",
        "Cancelled con data arrivo"
    ]
    
    df['Categoria_Errore'] = np.select(condizioni_errore, scelte_errore, default="Dati Validi")
    
    # ---------------------------------------------------------
    # 5. FLAG INSUCCESSO (Per Query 4.3)
    # ---------------------------------------------------------
    df['Insuccesso_Flag'] = np.where(df['status'].isin(['Delayed', 'Cancelled']), 1, 0)

    # Salvo il file CSV per Power BI
    df.to_csv('dashboard_dataset.csv', index=False, decimal=',')
    print("[SUCCESS] Dataset 'dashboard_dataset.csv' arricchito, generato e salvato correttamente")
    
    conn.close()

if __name__ == "__main__":
    main()