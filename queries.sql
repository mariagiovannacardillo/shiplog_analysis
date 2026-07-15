-- =========================================================================================
-- PROGETTO: Esercizio Take-Home Junior Data Analyst - Albini & Pitigliani S.p.A.
-- OBIETTIVO: Esplorazione DB ShipLog, risposta alle domande guida e data quality check.
-- RDBMS TARGET: SQLite
-- CANDIDATA: Maria Giovanna Cardillo
-- =========================================================================================

-- ------------------------------------------
-- DOMANDA 1: Top Clienti e Top Carrier
-- ------------------------------------------

-- ------------------------------------------
-- 1. TOP CLIENTI
-- ------------------------------------------

-- 1.1. Top Clienti (Numero Spedizioni)
SELECT c.customer_name, COUNT(s.shipment_id) as numero_spedizioni
FROM shipments s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY numero_spedizioni DESC LIMIT 5;

-- 1.2. Top Clienti (Volumi Fisici Spediti CBM)
SELECT c.customer_name, SUM(s.volume_cbm) as volumi_spediti
FROM shipments s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY volumi_spediti DESC LIMIT 5;

-- 1.3. Top Clienti (Spesa Totale)
SELECT c.customer_name, SUM(s.freight_cost_eur) as spesa_totale
FROM shipments s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY spesa_totale DESC LIMIT 5;

-- -----------------------------------------------------------------------------------------
-- 1.4. Top Clienti (Vista Unificata)
-- Questa vista aggrega la spesa totale, il numero di spedizioni e i volumi fisici (CBM).
-- L'ordinamento primario è basato sulla spesa totale, utilizzando il numero di spedizioni e
-- i volumi come tie-breaker (spareggio) a parità di spesa.
-- -----------------------------------------------------------------------------------------
SELECT c.customer_name, SUM(s.freight_cost_eur) AS spesa_totale, COUNT(s.shipment_id) AS numero_spedizioni, SUM(s.volume_cbm) as volumi_spediti
FROM shipments s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY spesa_totale DESC, numero_spedizioni DESC, volumi_spediti DESC LIMIT 5;

-- ------------------------------------------
-- 1. TOP CARRIER
-- ------------------------------------------

-- 1.5. Top Carrier (Numero Spedizioni)
SELECT car.carrier_name, COUNT(s.shipment_id) as numero_spedizioni
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
GROUP BY car.carrier_name
ORDER BY numero_spedizioni DESC LIMIT 5;

-- 1.6. Top Carrier (Volumi Fisici Spediti CBM)
SELECT car.carrier_name, SUM(s.volume_cbm) as volumi_spediti
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
GROUP BY car.carrier_name
ORDER BY volumi_spediti DESC LIMIT 5;

-- 1.7. Top Carrier (Spesa Totale)
SELECT car.carrier_name, SUM(s.freight_cost_eur) as spesa_totale
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
GROUP BY car.carrier_name
ORDER BY spesa_totale DESC LIMIT 5;

-- ----------------------------------------------------------------------------
-- 1.8. Top Carrier (Vista Unificata)
-- Mostra i partner logistici più strategici. Incrociare spesa e volumi 
-- permette di capire non solo chi viene utilizzato di più, ma anche chi incide 
-- maggiormente sul budget aziendale.
-- ----------------------------------------------------------------------------
SELECT car.carrier_name, SUM(s.freight_cost_eur) AS spesa_totale, COUNT(s.shipment_id) AS numero_spedizioni, SUM(s.volume_cbm) as volumi_spediti
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
GROUP BY car.carrier_name
ORDER BY spesa_totale DESC, numero_spedizioni DESC, volumi_spediti DESC LIMIT 5;

-- ------------------------------------------
-- 1. TOP CLIENTI E CARRIER 
-- ------------------------------------------

-- 1.9. Top Clienti e Carrier (Vista Unificata)
SELECT c.customer_name, car.carrier_name, SUM(s.freight_cost_eur) AS spesa_totale, COUNT(s.shipment_id) AS numero_spedizioni, SUM(s.volume_cbm) as volumi_spediti
FROM shipments s
JOIN customers c ON s.customer_id = c.customer_id
JOIN carriers car ON s.carrier_id = car.carrier_id
GROUP BY c.customer_name, car.carrier_name
ORDER BY spesa_totale DESC, numero_spedizioni DESC, volumi_spediti DESC LIMIT 5;


-- ---------------------------------------------------------
-- DOMANDA 2: Distribuzione Spedizioni per Modalità e Stato
-- ---------------------------------------------------------

-- ----------------------------------------------------------------------
-- 2.1. Distribuzione per Modalità di Trasporto (Macro)
-- Questa query analizza le modalità di trasporto (mare, aereo o strada), 
-- fornendo la percentuale di ogni mezzo sul totale delle spedizioni.
-- ----------------------------------------------------------------------
SELECT 
    mode, 
    COUNT(shipment_id) AS numero_spedizioni,
    ROUND(COUNT(shipment_id) * 100.0 / (SELECT COUNT(*) FROM shipments), 2) AS percentuale_totale
FROM shipments
GROUP BY mode
ORDER BY numero_spedizioni DESC;

-- --------------------------------------------------------------------------------------------------------------------
-- 2.2. Distribuzione per Stato (Macro)
-- Questa query è il "termometro" della salute logistica generale. 
-- Mostra quanti ordini vanno a buon fine, quanti sono in ritardo e quanti vengono cancellati in proporzione al totale.
-- --------------------------------------------------------------------------------------------------------------------
SELECT 
    status, 
    COUNT(shipment_id) AS numero_spedizioni,
    ROUND(COUNT(shipment_id) * 100.0 / (SELECT COUNT(*) FROM shipments), 2) AS percentuale_totale
FROM shipments
GROUP BY status
ORDER BY numero_spedizioni DESC;

-- -----------------------------------------------------------------------
-- 2.3. Vista Unificata (Incrocio Mode/Status)
-- Questa query unifica ed incrocia il mode con lo status. 
-- Con l'uso di OVER PARTITION BY calcoliamo la percentuale di ogni stato 
-- all'interno del suo specifico mezzo di trasporto.
-- -----------------------------------------------------------------------
SELECT 
    mode, 
    status, 
    COUNT(shipment_id) AS numero_spedizioni,
    ROUND(COUNT(shipment_id) * 100.0 / SUM(COUNT(shipment_id)) OVER (PARTITION BY mode), 2) AS percentuale_su_mezzo
FROM shipments 
GROUP BY mode, status 
ORDER BY mode ASC, numero_spedizioni DESC;

-- -------------------------------------------------------------------------
-- 2.4. Tassi di Affidabilità, Ritardo e Cancellazione (Pivot)
-- Questa query evidenzia i pattern di performance dei vari mezzi.
-- Risponde alle domande: Qual è il mezzo più sicuro? 
-- Quale ha la % maggiore di ritardi? Ci sono anomalie nelle cancellazioni?
-- -------------------------------------------------------------------------
SELECT 
    mode,
    COUNT(shipment_id) AS spedizioni_totali,
    SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) AS spedizioni_delivered,
    SUM(CASE WHEN status = 'Delayed' THEN 1 ELSE 0 END) AS spedizioni_delayed,
    SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS spedizioni_cancelled,
    -- Calcolo delle percentuali per evidenziare i pattern
    ROUND(SUM(CASE WHEN status = 'Delayed' THEN 1 ELSE 0 END) * 100.0 / COUNT(shipment_id), 2) AS percentuale_ritardo,
    ROUND(SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(shipment_id), 2) AS percentuale_cancellazioni
FROM shipments
GROUP BY mode
ORDER BY percentuale_ritardo DESC;

-- ------------------------------------------------------------------------
-- 2.5. Tasso Medio di Transito
-- Calcola quanti giorni impiega in media ogni mezzo di trasporto.
-- Sfrutta la funzione julianday() per estrarre la differenza matematica
-- tra la data di partenza e quella di arrivo per i soli ordini consegnati.
-- ------------------------------------------------------------------------
SELECT 
    mode,
    COUNT(shipment_id) AS numero_spedizioni_consegnate,
    ROUND(AVG(julianday(arrival_date) - julianday(departure_date)), 1) AS tempo_medio_transito_giorni
FROM shipments
WHERE status = 'Delivered' 
  AND arrival_date IS NOT NULL 
  AND departure_date IS NOT NULL
GROUP BY mode
ORDER BY tempo_medio_transito_giorni ASC;

-- ------------------------------------------------------------------------------------------
-- 2.6. Incrocio Ritardi vs Aree Geografiche (Colli di Bottiglia)
-- Identifica le tratte più problematiche analizzando l'origine e la destinazione.
-- Il filtro HAVING esclude le tratte con una sola spedizione per non falsare le statistiche.
-- ------------------------------------------------------------------------------------------
SELECT 
    origin_country,
    destination_country,
    COUNT(shipment_id) AS spedizioni_totali,
    SUM(CASE WHEN status = 'Delayed' THEN 1 ELSE 0 END) AS spedizioni_in_ritardo,
    ROUND(SUM(CASE WHEN status = 'Delayed' THEN 1 ELSE 0 END) * 100.0 / COUNT(shipment_id), 2) AS percentuale_ritardo
FROM shipments
GROUP BY origin_country, destination_country
HAVING spedizioni_totali > 1
-- Aggiungo un filtro per visualizzare le tratte decrescenti per criticità
ORDER BY percentuale_ritardo DESC, spedizioni_totali DESC;

-- ----------------------------------------------------------------
-- DOMANDA 4: Metrica Chiave
-- ----------------------------------------------------------------

-- -------------------------------------------------------------------------
-- TRE METRICHE SCELTE:  
-- 1. Visione Macro Globale
-- 2. Tasso di Insuccesso Settimanale
-- 3. Tasso di Insuccesso Settimanale per Carrier
-- Percentuale di spedizioni Delayed + Cancelled sul totale.
-- PERCHÈ: È un "Leading Indicator" (indicatore predittivo). Monitorare 
-- semplicemente i volumi racconta il passato; monitorare i ritardi 
-- permette di prevedere i colli di bottiglia e prevenire i reclami dei 
-- Top Clienti prima che diventino critici.
-- -------------------------------------------------------------------------

-- 4.1. Visione Macro Globale
SELECT status, COUNT(*) as totale, ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM shipments), 2) as percentuale
FROM shipments 
GROUP BY status;

-- ----------------------------------------------------------------------
-- 4.2. Tasso di Insuccesso Settimanale (Trend)
-- Raggruppa i dati per settimana (Anno-Settimana) mostrando l'andamento
-- della percentuale di fallimento o ritardo nel tempo.
-- ----------------------------------------------------------------------
SELECT 
    strftime('%Y-%W', booking_date) AS anno_settimana,
    COUNT(shipment_id) AS totale_spedizioni,
    SUM(CASE WHEN status IN ('Delayed', 'Cancelled') THEN 1 ELSE 0 END) AS spedizioni_problematiche,
    ROUND(SUM(CASE WHEN status IN ('Delayed', 'Cancelled') THEN 1 ELSE 0 END) * 100.0 / COUNT(shipment_id), 2) AS tasso_insuccesso_percentuale
FROM shipments
WHERE booking_date IS NOT NULL AND TRIM(booking_date) != ''
GROUP BY anno_settimana
ORDER BY anno_settimana DESC;

-- ----------------------------------------------------------------
-- 4.3. Tasso di Insuccesso Settimanale per Carrier (Drill-down)
-- Permette di identificare immediatamente QUALE fornitore sta 
-- causando il picco di ritardi nella settimana corrente.
-- ----------------------------------------------------------------
SELECT 
    strftime('%Y-%W', s.booking_date) AS anno_settimana,
    car.carrier_name,
    COUNT(s.shipment_id) AS totale_spedizioni_affidate,
    SUM(CASE WHEN s.status IN ('Delayed', 'Cancelled') THEN 1 ELSE 0 END) AS spedizioni_problematiche,
    ROUND(SUM(CASE WHEN s.status IN ('Delayed', 'Cancelled') THEN 1 ELSE 0 END) * 100.0 / COUNT(s.shipment_id), 2) AS tasso_insuccesso_percentuale
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
WHERE s.booking_date IS NOT NULL AND TRIM(s.booking_date) != ''
GROUP BY anno_settimana, car.carrier_name
ORDER BY anno_settimana DESC, tasso_insuccesso_percentuale DESC;

-- -----------------------------------------------------------------------------------------
-- PLUS 4.4. On-Time Delivery Rate (Metrica basata su SLA (Service Level Agreement) Teorico)
-- Calcolo della percentuale di spedizioni consegnate entro un tempo limite 
-- (SLA) definito per ogni modalità di trasporto (Air <=7gg, Road <=14gg, Sea <=45gg).
-- ------------------------------------------------------------------------------------------- ------------------------------------------------------------
-- Non essendo presente nel db un campo promised_delivery_date per valutare i ritardi, 
-- ho deciso di calcolare l'On-Time Delivery Rate strutturando uno SLA (Service Level Agreement) teorico. 
-- Ho assegnato a ciascuna modalità di trasporto una soglia limite di transito (7 giorni per l'aereo, 14 per la strada, 45 per il mare). 
-- Calcolando matematicamente i giorni effettivi di viaggio delle spedizioni tramite la funzione julianday() per sottrare l'arrival_date al departure_date, 
-- la query categorizza automaticamente come 'in ritardo' le spedizioni che eccedono rispetto ai giorni impostati nello SLA. 
-- Questa metrica è, a mio avviso, una delle più critiche e perciò la monitorerei settimanalmente per valutare l'affidabilità dei Carrier,
-- così da poter misurare le performance operative.
-- ------------------------------------------------------------------------------------------- ------------------------------------------------------------
SELECT 
    car.carrier_name,
    s.mode,
    COUNT(s.shipment_id) AS spedizioni_totali,
    -- Contiamo quante spedizioni rispettano lo SLA calcolando la differenza di giorni
    SUM(CASE 
        WHEN s.mode = 'Air' AND (julianday(s.arrival_date) - julianday(s.departure_date)) <= 7 THEN 1
        WHEN s.mode = 'Road' AND (julianday(s.arrival_date) - julianday(s.departure_date)) <= 14 THEN 1
        WHEN s.mode = 'Sea' AND (julianday(s.arrival_date) - julianday(s.departure_date)) <= 45 THEN 1
        ELSE 0 
    END) AS spedizioni_in_sla,
    
    -- Contiamo quante hanno violato lo SLA (sono arrivate in ritardo rispetto alle attese)
    SUM(CASE 
        WHEN s.mode = 'Air' AND (julianday(s.arrival_date) - julianday(s.departure_date)) > 7 THEN 1
        WHEN s.mode = 'Road' AND (julianday(s.arrival_date) - julianday(s.departure_date)) > 14 THEN 1
        WHEN s.mode = 'Sea' AND (julianday(s.arrival_date) - julianday(s.departure_date)) > 45 THEN 1
        ELSE 0 
    END) AS spedizioni_in_ritardo,

    -- Calcoliamo la percentuale di successo (L'On-Time Delivery Rate)
    ROUND(SUM(CASE 
        WHEN s.mode = 'Air' AND (julianday(s.arrival_date) - julianday(s.departure_date)) <= 7 THEN 1
        WHEN s.mode = 'Road' AND (julianday(s.arrival_date) - julianday(s.departure_date)) <= 14 THEN 1
        WHEN s.mode = 'Sea' AND (julianday(s.arrival_date) - julianday(s.departure_date)) <= 45 THEN 1
        ELSE 0 
    END) * 100.0 / NULLIF(COUNT(s.shipment_id), 0), 2) AS on_time_delivery_rate_perc

FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
WHERE s.status = 'Delivered' 
  AND s.departure_date IS NOT NULL 
  AND s.arrival_date IS NOT NULL
  AND s.mode = car.mode -- Filtro di Data Quality
GROUP BY car.carrier_name, s.mode
-- Ordinamento partendo dalle performance peggiori per individuare i colli di bottiglia
ORDER BY s.mode ASC, on_time_delivery_rate_perc ASC;


-- ---------------------------------------------------------
-- APPROFONDIMENTO COSTI: Costo medio per Kg e per CBM
-- Calcolo al netto delle anomalie di disallineamento 
-- 'mode' tra le tabelle shipments e carriers.
-- Permette di identificare quali Carrier sono più costosi 
-- per singola unità trasportata, a parità di mezzo (mode).
-- L'uso di NULLIF previene errori di divisione per zero.
-- ---------------------------------------------------------
SELECT 
    car.carrier_name,
    car.mode AS modalita_ufficiale_carrier,
    ROUND(AVG(s.freight_cost_eur / NULLIF(s.weight_kg, 0)), 2) AS costo_medio_per_kg_eur,
    ROUND(AVG(s.freight_cost_eur / NULLIF(s.volume_cbm, 0)), 2) AS costo_medio_per_cbm_eur
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
WHERE s.weight_kg > 0 
  AND s.volume_cbm > 0
  AND s.mode = car.mode -- <--- FILTRO
GROUP BY car.carrier_name, car.mode
ORDER BY car.mode, costo_medio_per_kg_eur DESC;

-- -----------------------------------------------------------------------
-- APPROFONDIMENTO COSTI: Costo medio per Kg e per CBM (TABELLA SBAGLIATA)
-- Calcolo che non tiene conto delle anomalie di disallineamento 
-- 'mode' tra le tabelle shipments e carriers.
-- -----------------------------------------------------------------------
SELECT 
    car.carrier_name,
    s.mode AS modalita_registrata_spedizione,
    ROUND(AVG(s.freight_cost_eur / NULLIF(s.weight_kg, 0)), 2) AS costo_medio_per_kg_eur,
    ROUND(AVG(s.freight_cost_eur / NULLIF(s.volume_cbm, 0)), 2) AS costo_medio_per_cbm_eur
FROM shipments s
JOIN carriers car ON s.carrier_id = car.carrier_id
WHERE s.weight_kg > 0 AND s.volume_cbm > 0
GROUP BY car.carrier_name, s.mode
ORDER BY s.mode, costo_medio_per_kg_eur DESC;




