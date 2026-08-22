# ShipLog: Analisi Spedizioni e Data Quality
## 1. Metodologia, Strumenti e Approccio
Questo repository contiene l'esito dell'esplorazione del database `shiplog.db`. L'obiettivo principale è stato non solo rispondere alle domande di business ma, parallelamente, condurre un *Data Quality Audit* per valutare l'affidabilità dell'infrastruttura dati e del dato sottostante.

### 1.1 Strumenti Utilizzati
* **Beekeeper Studio:** Utilizzato per la prima esplorazione "tattile" del database, per lo studio dello schema relazionale e per la stesura e validazione di tutto il codice SQL.
* **Python (sqlite3, pandas, numpy):** Impiegato come layer intermedio di *Data Preparation*. È stato utilizzato per estrarre i dati, calcolare metriche complesse (es. giorni di transito) e applicare le logiche di normalizzazione per le tabelle di BI.
* **Microsoft Power BI:** Scelto per la *Data Visualization*, traducendo l'output delle query in una dashboard direzionale interattiva.
* **GitHub:** Per il versioning del codice e la consegna strutturata del progetto.

### 1.2 Approccio all'Esplorazione e Gestione dei Dati Imperfetti
Di fronte a un dataset sconosciuto, il mio approccio parte sempre dalla validazione dell'integrità strutturale. La mia filosofia nella gestione dei "dati imperfetti" è **non eliminare mai il dato anomalo in fase di analisi, ma di isolarlo**. 
Eliminare un record anomalo (es. un peso negativo) compromette la visibilità del problema. Ho preferito escludere le anomalie dai calcoli di business (per non falsare i dati), convogliandole in un "Diagnostic Log" (Query 19, Master View) strutturato tramite `UNION ALL` da restituire al team operativo per la bonifica a sistema.

---

## 2. Risposte alle Domande Guida

### 🔍 Domanda 1: Top Clienti, Carrier e Anomalie Anagrafiche
L'analisi (Query 1.4 e 1.8) ha permesso di mappare i partner logistici strategici incrociando spesa e volumi, visualizzati nella Dashboard tramite grafici a dispersione (Scatter Plot) per valutare l'efficienza di carico.

**Data Quality e Anomalie Strutturali:**
Esplorando visivamente le tabelle, ho riscontrato una totale assenza di normalizzazione. L'indagine diagnostica ha fatto emergere profonde criticità a livello di regole di business. Ho individuato queste anomalie progettando un set di query in cui ho tradotto le regole base della logistica in condizioni SQL.

**Il disallineamento dei Costi (Data Quality):**
Per valutare l'efficienza economica ho strutturato delle query (APPROFONDIMENTO COSTI) per calcolare il costo medio per Kg e per CBM. Durante questa operazione di calcolo per l'efficienza dei costi per vettore, è emersa un'anomalia grave: la modalità di trasporto (`mode`) registrata nella tabella `shipments` entrava spesso in conflitto con la modalità ufficiale registrata in `carriers` (es. vettori marittimi associati a tariffe aeree e viceversa). 
* **Soluzione adottata:** Per evitare di restituire metriche fuorvianti, ho normalizzato l'analisi applicando un filtro di coerenza logica (`WHERE s.mode = car.mode`) per calcolare i costi unitari esclusivamente sui record coerenti, isolando i dati "sporchi" per una successiva bonifica.

### 📊 Domanda 2: Distribuzione per Modalità e Stato
Attraverso le Query 2.3 (Incrocio Mode/Status) è stata calcolata la percentuale di ogni stato all'interno del suo specifico mezzo di trasporto. La Query 2.4 (Tassi di Affidabilità, Ritardo e Cancellazione) ha permesso di evidenziare i pattern logistici, identificando chiaramente quale mezzo presenta il tasso di ritardo e cancellazione maggiore. Dalla Dashboard emerge chiaramente l'incidenza di ritardi e cancellazioni sulle diverse rotte.
* Sono stati calcolati il **Tasso di Affidabilità**  e il **Tempo Medio di Transito** (Query 2.5), ovvero i giorni impiegati in media da ogni mezzo calcolati sulle date effettive, per approfondire i ritardi e per capire quale mezzo garantisca le performance migliori e quale generi il maggior numero di colli di bottiglia. Con la query 2.6 (analizzando l'origine e la destinazione delle tratte), vengono incrociati i ritardi con le **Aree Geografiche**, permettendo di mappare visivamente le tratte (origine-destinazione) più problematiche del network logistico.

### 🚨 Domanda 3: Dati Sospetti e Indagine Diagnostica
Traducendo le regole della logistica in condizioni SQL, ho fatto emergere criticità strutturali profonde dovute all'assenza di vincoli nel database (`FOREIGN KEY`, `NOT NULL`, `CHECK`).

**Tipologie di anomalie individuate e possibili problematiche:**
1. **Duplicati Anagrafici:** Le anagrafiche clienti e carrier sono frammentati. Presentano record sdoppiati come *"Pinnacle Electronics"*, o *"Atlantic Furniture Co"* (con e senza punto finale). Stesso problema per i vettori (*"Maersk"* vs *"Maersk Line"*).
2. **Dati Orfani e Mancanti:** Il cliente *"Coastal Imports"* è privo del dato relativo alla nazione (`country IS NULL`). È possibile inserire spedizioni assegnate a corrieri (`carrier_id`) o clienti (`customer_id`) inesistenti, lasciare campi obbligatori vuoti (`DEFAULT VALUE IS NULL`), e lasciare clienti a sistema ma totalmente inattivi.
3. **Errori di Status Logico:** Possibilità di inserire ordini marcati come `Cancelled` con una data di arrivo valorizzata, o ordini `Delivered` privi di informazioni vitali (data di arrivo o nazioni mancanti).
4. **Incongruenze Temporali Viaggi nel Tempo:** Possibilità di inserimento di date di arrivo  (`arrival_date`) registrate prima della data di partenza (`departure_date`), o partenze antecedenti alla data di prenotazione (`booking_date`).
5. **Anomalie Economiche e Fisiche:** Valori negativi o pari a zero impossibili nel peso (`weight_kg`), volumi (`volume_cbm`) o costo di trasporto (`freight_cost_eur`).

*(Nota: L'elenco completo dei record compromessi è generato tramite la Master View SQL - Query 19).*

**Piano di Risoluzione (Correzione e Prevenzione):**
* **Fase 1 (Operativa - Data Cleansing):** Isolare i record, recuperare il dato reale con i referenti e utilizzare istruzioni `UPDATE` per correggere lo storico (es. convertire in `ABS()` i pesi negativi e accorpare le anagrafiche duplicate sotto un singolo ID, eliminando le ridondanze con `DELETE`).
* **Fase 2 (Strutturale - DB Hardening):** Poiché SQLite limita il comando `ALTER TABLE`, l'azione prioritaria è la creazione di una nuova tabella `shipments_new` per travasarvi i dati puliti. La nuova tabella integrerà:
  * Vincoli `FOREIGN KEY` (`ON DELETE RESTRICT`) per evitare dati orfani.
  * Vincoli `CHECK (weight_kg > 0)` per bloccare input numerici errati.
  * Domini chiusi `CHECK (status IN ('Delivered', 'Delayed'...))` per evitare refusi di battitura.
  * Conversione del tipo `TEXT` in `DATE` per applicare rigidi controlli temporali in fase di inserimento.
Dopo aver travasato i dati puliti, la tabella andrà rinominata per rimetterla in produzione e si potrà a quel punto cancellare la vecchia tabella.

### 🎯 Domanda 4: La Metrica Strategica da Monitorare
Se dovessi scegliere un singolo KPI da monitorare settimanalmente, opterei per una duplice visione:
1. **Tasso di Insuccesso Settimanale per Carrier (Query 4.3):** Un *Leading Indicator* (metrica predittiva). Monitorare la % di spedizioni `Delayed` e `Cancelled` permette di anticipare i colli di bottiglia e prevenire i reclami.
2. **On-Time Delivery Rate (Query 4.4):** Non essendo presente un campo `promised_delivery_date`, ho strutturato tramite Python/Pandas uno SLA (Service Level Agreement) teorico basato sui giorni netti di transito (Air <=7gg, Road <=14gg, Sea <=45gg). Misurare le performance reali contro questo SLA fornisce il reale polso dell'affidabilità logistica.

---

## 3. Il Ruolo dell'Intelligenza Artificiale (AI)
In linea con le policy aziendali, dichiaro di aver utilizzato strumenti di intelligenza artificiale generativa (LLM) durante questo progetto con un approccio *"Sparring Partner"*.
L'AI mi è stata utile per:
* Confrontarmi sulle best practices di Data Visualization (es. la scelta di separare i grafici a dispersione tra Clienti e Carrier per evitare rumore visivo).
* **Cosa ho delegato:** La stesura del codice boilerplate in Python (es. il parsing delle date con pandas) per la preparazione del dataset piatto per Power BI, delegando all'AI la stesura sintattica dei calcoli temporali che avevo precedentemente definito in logica SQL e l'impaginazione formattata del Markdown. La stesura e revisione di alcune Query SQL, come per la logica dietro la Master View degli allarmi (Query 19), ottimizzandola con l'uso di `UNION ALL` per ragioni di performance computazionale (escludendo il controllo dei duplicati).
* **Cosa ho imparato:** Ho compreso che l'AI è un eccellente esecutore sintattico, ma manca totalmente di sensibilità al dominio logistico. La definizione dello SLA teorico, la caccia alle anomalie anagrafiche, la scoperta dei "viaggi nel tempo" e l'architettura di Database Hardening per arginare i limiti di SQLite sono stati concepiti e validati interamente dal mio ragionamento analitico. 

## 4. Alternative Scartate e Sviluppi Futuri
* **Alternative Scartate:** Inizialmente avevo ipotizzato di unificare i Top Clienti e i Top Carrier in un unico grafico a dispersione. Ho scartato l'idea per evitare "rumore visivo": mischiare "chi paga l'azienda" con "chi viene pagato dall'azienda" avrebbe generato confusione nella lettura manageriale.
* **Sviluppi Futuri:** Avendo più tempo e un dataset storicizzato, avrei implementato un'analisi della stagionalità anno su anno (YoY) e integrato un campo reale `promised_delivery_date` per misurare i ritardi effettivi tramite dashboard, anziché basarmi su uno SLA teorico. Avrei approfondito ulteriormente l'Analisi dei Costi, studiando ad esempio l'impatto del peso volumetrico rispetto al peso reale e valutando la marginalità delle singole tratte. Avrei inoltre integrato un sistema di alerting automatico collegato alla Master View delle anomalie. 
