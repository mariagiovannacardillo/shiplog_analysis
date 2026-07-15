-- =========================================================================================
-- PROGETTO: Esercizio Take-Home Junior Data Analyst - Albini & Pitigliani S.p.A.
-- OBIETTIVO: Esplorazione DB ShipLog, risposta alle domande guida e data quality check.
-- RDBMS TARGET: SQLite
-- CANDIDATA: Maria Giovanna Cardillo
-- =========================================================================================

-- ----------------------------------------------------------
-- DOMANDA 3: Indagine Diagnostica (Dati Sospetti e Anomalie)
-- ----------------------------------------------------------

-- 1. Spedizioni duplicate
SELECT shipment_id, COUNT(*) AS spedizioni_duplicate
FROM shipments
GROUP BY shipment_id
HAVING spedizioni_duplicate > 1;

-- 2. Controllo numero righe per tabella
SELECT 'shipments' AS table_name, COUNT(*) AS righe_totali FROM shipments;

SELECT 'customers' AS table_name, COUNT(*) AS righe_totali FROM customers;
  
SELECT 'carriers' AS table_name, COUNT(*) AS righe_totali FROM carriers;

-- 3. Controllo valori NULL per colonne chiave (ES. tabella shipments)
SELECT 
  SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer,
  SUM(CASE WHEN carrier_id IS NULL THEN 1 ELSE 0 END) AS null_carrier,
  SUM(CASE WHEN booking_date IS NULL THEN 1 ELSE 0 END) AS null_booking
FROM shipments;

-- 4. Carrier Name NULL
SELECT carrier_id, carrier_name 
FROM carriers 
WHERE carrier_name IS NULL OR TRIM(carrier_name) = '';

-- 5. Duplicati Carrier (es. Maersk)
SELECT carrier_id, carrier_name 
FROM carriers 
WHERE carrier_name LIKE '%Maersk%';

-- 6. Customer Name NULL
SELECT customer_id, customer_name 
FROM customers 
WHERE customer_name IS NULL OR TRIM(customer_name) = '';

-- 7. Duplicati Clienti (es. Pinnacle e Atlantic)
SELECT customer_id, customer_name 
FROM customers 
WHERE customer_name LIKE '%Pinnacle%' OR customer_name LIKE '%Atlantic%';

-- 8. Country NULL (Tabella Clienti)
SELECT customer_id, customer_name, country 
FROM customers 
WHERE country IS NULL OR TRIM(country) = '';

-- 9. Valori Negativi Impossibili (peso, volume o costo)
SELECT shipment_id, weight_kg, volume_cbm, freight_cost_eur 
FROM shipments 
WHERE weight_kg <= 0 OR volume_cbm <= 0 OR freight_cost_eur <= 0;

-- 10. Valori Negativi Impossibili per spedizioni in transito o consegnate (peso, volume o costo)
SELECT shipment_id, status, weight_kg, volume_cbm, freight_cost_eur
FROM shipments
WHERE (status IN ('In Transit', 'Delivered') AND (weight_kg <= 0 OR volume_cbm <= 0 OR freight_cost_eur <= 0));

-- 11. Errori temporali (ES. Data di arrivo precedente alla data di partenza)
SELECT shipment_id, booking_date, departure_date, arrival_date 
FROM shipments 
WHERE departure_date < booking_date OR arrival_date < departure_date;

-- 12. Errori temporali (ES. Spedizioni cancellate ma con una data di arrivo)
SELECT shipment_id, status, booking_date, departure_date, arrival_date 
FROM shipments 
WHERE (status = 'Delivered' AND arrival_date IS NULL)
   OR (status = 'In Transit' AND departure_date IS NULL)
   OR (status = 'Cancelled' AND arrival_date IS NOT NULL AND TRIM(arrival_date) != '');

-- 13. Ricerca spedizioni con cliente inesistente in anagrafica
SELECT s.shipment_id, s.customer_id 
FROM shipments s
LEFT JOIN customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 14. Ricerca spedizioni con carrier inesistente in anagrafica
SELECT s.shipment_id, s.carrier_id 
FROM shipments s
LEFT JOIN carriers car ON s.carrier_id = car.carrier_id
WHERE car.carrier_id IS NULL;

-- -------------------------------------------------------------------
-- 15. Ricerca clienti senza spedizioni
-- Utile per capire quali clienti non sono attivi.
-- -------------------------------------------------------------------
SELECT c.customer_id, c.customer_name, c.customer_segment
FROM customers c
LEFT JOIN shipments s ON c.customer_id = s.customer_id
WHERE s.shipment_id IS NULL;

-------------------------------------------------------------------
-- 16. Disallineamento della modalità di trasporto (mode)
-- Sia la tabella shipments che carriers possiedono la colonna mode. 
-- Questa query verifica se ci sono spedizioni dove la modalità registrata 
-- nell'ordine non coincide con quella del vettore.
-------------------------------------------------------------------
SELECT s.shipment_id, car.carrier_name, s.mode AS modalità_spedizione, car.mode AS modalità_vettore
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
WHERE s.mode != car.mode;

-------------------------------------------------------------------
-- 17. Verifica della standardizzazione degli Status (CHECK mancante)
-- Questa query rileva valori diversi da 'Delivered', 'Delayed', 'In Transit' o 'Cancelled'.
-------------------------------------------------------------------
SELECT shipment_id, status 
FROM shipments 
WHERE status NOT IN ('Delivered', 'Delayed', 'In Transit', 'Cancelled')
   OR status IS NULL;

-------------------------------------------------------------------
-- 18. Verifica per incoerenza logica (ES. la spedizione è stata consegnata, ma dove? da dove era partita?)
-- Se un pacco risulta consegnato (Delivered), 
-- deve per forza avere una arrival_date e una nazione di origine/destinazione. 
-- Questi valori NON POSSONO ESSERE NULL.
-------------------------------------------------------------------
SELECT shipment_id, status, arrival_date, origin_country, destination_country
FROM shipments
WHERE status = 'Delivered' 
  AND (
    arrival_date IS NULL 
    OR TRIM(arrival_date) = '' 
    OR origin_country IS NULL 
    OR destination_country IS NULL
  );

-------------------------------------------------------------------
-- 19. MASTER VIEW (TABELLA RIASSUTIVA PER WARNING GENERALE)
-- La query, con il comando UNION ALL, restituisce una lista 
-- dove ti dice che tipo di errore ha trovato, dove, la descrizione, 
-- e su quale ID andare a indagare.
-------------------------------------------------------------------
-- Nota tecnica: È stato preferito l'uso di UNION ALL
-- rispetto al classico UNION per ottimizzare le performance di calcolo, 
-- in quanto in un log di errori non è necessario far eseguire al motore SQL il controllo dei duplicati.
-------------------------------------------------------------------

-- 19.1. Controllo Anagrafiche: Customer senza nazione
SELECT 
    'Anagrafica Customer' AS categoria_errore, 
    'Country mancante per il cliente: ' || customer_name AS descrizione_problema, 
    customer_id AS id_record_problematico
FROM customers 
WHERE country IS NULL OR TRIM(country) = ''

UNION ALL

-- 19.2. Controllo Anagrafiche: Carrier senza nome
SELECT 
    'Anagrafica Carrier', 
    'Nome corriere mancante o vuoto', 
    carrier_id
FROM carriers 
WHERE carrier_name IS NULL OR TRIM(carrier_name) = ''

UNION ALL

-- 19.3. Controllo Qualità: Valori Negativi in Spedizioni
SELECT 
    'Dati Spedizione', 
    'Trovati valori negativi/zero (peso, volume o costo)', 
    shipment_id
FROM shipments 
WHERE weight_kg <= 0 OR volume_cbm <= 0 OR freight_cost_eur <= 0

UNION ALL

-- 19.4. Controllo Logica Temporale: Partenze prima delle prenotazioni
SELECT 
    'Logica Temporale', 
    'La data di partenza precede la data di prenotazione', 
    shipment_id
FROM shipments 
WHERE departure_date < booking_date

UNION ALL

-- 19.5. Controllo Logica Temporale: Arrivi prima delle partenze
SELECT 
    'Logica Temporale', 
    'La data di arrivo precede la data di partenza', 
    shipment_id
FROM shipments 
WHERE arrival_date < departure_date

UNION ALL

-- 19.6. Controllo Incoerenza: Cancelled con data arrivo
SELECT 
    'Incoerenza Status', 
    'Spedizione Cancellata ma con data di arrivo', 
    shipment_id
FROM shipments 
WHERE status = 'Cancelled' 
  AND arrival_date IS NOT NULL 
  AND TRIM(arrival_date) != ''

UNION ALL

-- 19.7. Controllo Incoerenza: Delivered senza dati essenziali
SELECT 
    'Incoerenza Status', 
    'Pacco Consegnato ma mancano info su date o geolocalizzazione', 
    shipment_id
FROM shipments 
WHERE status = 'Delivered' 
  AND (
      arrival_date IS NULL OR TRIM(arrival_date) = '' 
      OR origin_country IS NULL 
      OR destination_country IS NULL
  );

-- ================================================================
-- RISOLUZIONE DELLE ANOMALIE (PIANO D'AZIONE STRUTTURALE)
-- ================================================================
/*
Per correggere e prevenire questi errori, è necessario un doppio intervento:

1. FASE OPERATIVA (Data Cleansing):
   - Uso istruzioni UPDATE per correggere i valori in negativo (es. UPDATE shipments SET weight_kg = ABS(weight_kg) WHERE weight_kg < 0).
   - Uso UPDATE per assegnare i carrier duplicati a un unico ID univoco, per poi eliminare il duplicato (DELETE).

2. FASE STRUTTURALE (Database Hardening):
   Poiché SQLite ha limiti sul comando ALTER TABLE, la best practice è:
   - Creare una nuova tabella "shipments_new".
   - Inserire vincoli di FOREIGN KEY su customer_id e carrier_id (ON DELETE RESTRICT).
   - Inserire vincoli logici: CHECK (weight_kg > 0), CHECK (freight_cost_eur > 0).
   - Inserire un dominio chiuso: CHECK (status IN ('Delivered', 'Delayed', 'In Transit', 'Cancelled')).
   - Inserire vincoli temporali: CHECK (departure_date >= booking_date).
   - Travasare i dati (INSERT INTO shipments_new SELECT * FROM shipments).
   - Sostituire le tabelle (DROP della vecchia, RENAME della nuova).
*/

