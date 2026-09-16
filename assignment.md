# Esercizio Take-Home - Junior Data Analyst
## ShipLog: un caso semplificato di analisi spedizioni

### Obiettivo del Progetto
Questo esercizio simula una reale richiesta di business per valutare l'approccio all'esplorazione di un dataset sconosciuto, la gestione di dati imperfetti e la capacità di estrarre e comunicare insight logistici. 

Non esiste una singola soluzione "corretta"; l'obiettivo è dimostrare profondità di analisi, capacità di problem-solving e chiarezza espositiva.

### Il Contesto
ShipLog è un database semplificato (e completamente fittizio) che simula le spedizioni gestite da un team di logistica internazionale. Contiene tre tabelle: clienti, vettori (carrier) e spedizioni.

| Tabella | Colonne principali | Descrizione |
| :--- | :--- | :--- |
| **customers** | `customer_id`, `customer_name`, `country`, `customer_segment` | Anagrafica clienti |
| **carriers** | `carrier_id`, `carrier_name`, `mode` | Anagrafica vettori/carrier |
| **shipments** | `shipment_id`, `customer_id`, `carrier_id`, `mode`, `origin_country`, `destination_country`, `booking_date`, `departure_date`, `arrival_date`, `weight_kg`, `volume_cbm`, `freight_cost_eur`, `status` | Spedizioni (420 righe) |

### Richieste di Business (Domande Guida)
Il management vuole capire meglio l'andamento delle spedizioni dell'ultimo periodo e identificare eventuali aree di attenzione. L'obiettivo è esplorare i dati e produrre un report strutturato che risponda alle seguenti domande:

1. **Analisi Partner:** Quali sono i clienti e i carrier più rilevanti per volume di spedizioni e/o costo di trasporto? C'è qualcosa che ti sembra strano osservando i dati anagrafici?
2. **Analisi Flussi:** Come si distribuiscono le spedizioni per modalità di trasporto (mare/aereo/strada) e per stato (consegnate, in transito, ritardate, cancellate)? Noti pattern interessanti?
3. **Data Quality Audit:** Ci sono spedizioni o valori che ti sembrano anomali o sospetti? Come li hai individuati, e cosa faresti per verificarli o correggerli?
4. **Definizione KPI:** Se tu dovessi scegliere una singola metrica strategica da monitorare ogni settimana per questo business, quale sceglieresti e perché?

### Deliverable Richiesti
*   Le **query SQL** utilizzate, con un breve commento sul funzionamento e sulle scelte logiche.
*   Un **riepilogo analitico** (report) con le osservazioni sulle 4 domande guida.
*   *Opzionale:* Una o più visualizzazioni a supporto (es. Power BI, Python, Excel).

### Vincoli e Strumenti
*   **Strumenti:** Piena libertà nell'utilizzo di tool (SQL, Python, BI) e strumenti di AI Generativa a patto di dichiararne e argomentarne l'uso.
