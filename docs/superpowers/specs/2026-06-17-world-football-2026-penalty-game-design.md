# World Football 2026 — Gioco di rigori (Design)

**Data:** 2026-06-17
**Stato:** Approvato per la pianificazione
**Piattaforma:** iPhone (iOS), SwiftUI + SpriteKit

## Sintesi

Gioco arcade di calcio a tocchi per iPhone, ambientato nella World Cup 2026
reale (48 nazioni, 12 gironi reali, calendario reale). La v1 include un solo
mini-gioco — i **rigori** — dentro una **Modalità Torneo**: il giocatore sceglie
una nazione e la porta dai gironi alla finale giocando shootout di rigori. Le
partite delle altre nazioni sono simulate. L'architettura è predisposta per
aggiungere altri mini-giochi in futuro (mix progressivo).

### Decisioni chiave

- **Genere:** arcade a tocchi.
- **Mini-gioco v1:** rigori (gli altri rimandati a versioni successive).
- **Tema:** World Cup 2026 reale — nomi e bandiere delle nazioni + gironi e
  calendario reali. **Niente** loghi/marchi FIFA, **niente** nomi di calciatori
  reali. Il nome del prodotto evita il marchio registrato "World Cup"
  (provvisorio: "World Football 2026").
- **Struttura:** Modalità Torneo, percorso della nazione del giocatore.
- **Tecnologia:** SwiftUI (shell/menu/schermate) + SpriteKit (gameplay).
- **Extra v1:** classifiche Game Center, audio (musica + effetti), salvataggio
  locale dei progressi.
- **Rimandato:** monetizzazione, altri mini-giochi, gironi giocabili da altre
  nazioni, modalità "gioca tutte le partite".

## Esperienza di gioco

### Controllo del rigore (in attacco)

Swipe direzionale con potenza ed effetto, gesto unico:

1. Il giocatore tocca vicino al pallone e trascina verso la porta. Durante il
   trascinamento una traiettoria-guida tratteggiata mostra la direzione.
2. Al rilascio: **direzione** dello swipe = mira; **velocità/lunghezza** =
   potenza; **curvatura** del gesto = effetto.
3. Più potenza riduce la precisione (margine d'errore casuale crescente) →
   meccanica rischio/ricompensa.

### Controllo della parata (in difesa)

Stesso gesto: quando il rigore avversario arriva, lo swipe determina la
direzione del tuffo del portiere. Coerenza di input tra attacco e difesa.

### IA del portiere avversario

Sceglie un tuffo. La difficoltà cresce con la **forza** della nazione avversaria
(turni avanzati = lettura migliore di direzione e timing). Parametri forniti dal
TournamentEngine.

### La partita = uno shootout

Ogni partita giocata è uno shootout: **5 tiri per parte alternati**
(il giocatore tira e para), poi **oltranza / sudden death** in caso di parità.
Nei gironi lo shootout produce sempre un vincitore (nessun pareggio).

## Modalità Torneo (struttura WC2026 reale)

- Il giocatore sceglie una nazione tra le 48 qualificate.
- **Fase a gironi:** 12 gironi da 4. Il giocatore gioca le **3** partite della
  propria nazione come shootout; le altre partite del torneo sono **simulate**.
  - Vittoria shootout = 3 punti, sconfitta = 0 (nessun pareggio).
  - Classifica per punti, poi differenza-rigori.
  - Avanzano: prime 2 di ogni girone (24) + le **8 migliori terze** → 32 squadre.
- **Eliminazione diretta:** Sedicesimi (32) → Ottavi → Quarti → Semifinale →
  Finale. Ogni turno della nazione del giocatore è uno shootout; gli altri
  incroci sono simulati.
- Percorso tipico del giocatore: ~3 partite gironi + fino a 5 a eliminazione ≈
  **7-8 shootout** per vincere il torneo.
- Vittoria finale → schermata trofeo + invio punteggio a Game Center.
- Sconfitta a eliminazione → torneo concluso, possibilità di ricominciare.

## Architettura

Due strati: **SwiftUI** per navigazione/menu/schermate statiche, **SpriteKit**
per il gameplay in tempo reale, collegati da un sottile strato di stato
condiviso. **La logica di gioco non dipende da SpriteKit né da SwiftUI**, per
poter essere testata in isolamento e per poter cambiare la grafica senza rompere
le regole.

### Moduli

- **App Shell (SwiftUI)** — menu principale, selezione nazione, schermata
  torneo/bracket, classifiche dei gironi, impostazioni, classifiche Game Center.
  Naviga tra schermate e lancia la scena di gioco.
- **GameKitBridge** — incapsula SpriteKit. `PenaltyScene` (`SKScene`) presentata
  in SwiftUI via `SpriteView`. La shell chiede "gioca un rigore/shootout" e
  riceve un risultato; non conosce la fisica.
- **PenaltyEngine** — logica del singolo rigore: interpreta lo swipe
  (direzione/potenza/curva), determina gol/parata/palo/fuori contro la posizione
  del portiere, con margine d'errore basato sulla potenza. Logica pura,
  deterministica con seed fisso, separata dalla resa grafica.
- **TournamentEngine** — progressione: gironi, classifiche, qualificazione
  (prime 2 + migliori terze), costruzione del tabellone, avanzamento/
  eliminazione. Lavora su dati, nessuna dipendenza da SpriteKit. Riceve "esito
  shootout", produce "prossima partita o esito torneo".
- **DataStore** — caricamento nazioni e calendario, e persistenza (salvataggio
  torneo in corso + record). Modelli `Codable`.
- **Services**
  - `AudioManager` — musica menu + effetti (tiro/parata/gol/folla),
    disattivabile, iniettabile (no-op nei test).
  - `LeaderboardService` — Game Center, login opzionale, gioco funzionante
    offline.
  - `MatchSimulator` — funzione pura: due nazioni + forze → risultato plausibile
    (con casualità per le sorprese). Riempie gironi e tabellone.

## Dati

- `nations.json` — 48 nazionali: nome, codice/asset bandiera, **forza** (1-100,
  da ranking pubblici) usata per IA portiere e simulazione.
- `tournament.json` — 12 gironi reali + calendario reale (squadre, date, sedi)
  della WC2026. Dataset reale recuperato in fase di implementazione (dati
  fattuali; nessun marchio FIFA incluso).
- Caricati all'avvio come modelli `Codable`.

## Persistenza

- Stato del torneo salvato in modo atomico come file `Codable` dopo **ogni**
  partita: nazione scelta, classifiche gironi, tabellone, turno corrente,
  statistiche (gol/parate). Chiudi e riprendi senza perdite.
- Record personali (miglior punteggio, tornei vinti) salvati a parte.

## Punteggio (Game Center)

Punteggio totale a fine torneo calcolato da: gol segnati, parate, vittorie e
bonus per torneo vinto. Inviato alla classifica Game Center. Login opzionale.

## Gestione errori

- **Game Center non disponibile / offline:** il gioco prosegue; l'invio del
  punteggio viene saltato o messo in coda, nessun blocco.
- **Audio non disponibile:** `AudioManager` degrada silenziosamente (no-op).
- **Salvataggio corrotto/assente:** si riparte da un nuovo torneo; il file
  corrotto viene archiviato/ignorato senza crash.
- **Dati mancanti:** i JSON di nazioni/calendario sono inclusi nel bundle; un
  errore di parsing è un fallimento di sviluppo coperto dai test, non un caso
  runtime per l'utente.

## Strategia di test (TDD)

- **PenaltyEngine:** dato swipe (vettore + curva) e posizione portiere → esito
  atteso deterministico con seed fisso.
- **TournamentEngine:** classifiche gironi corrette; qualificazione prime 2 +
  migliori terze; costruzione tabellone; avanzamento/eliminazione.
- **MatchSimulator:** con seed fisso, distribuzione risultati coerente con le
  forze relative.
- **Persistenza:** salva → ricarica → stato identico (round-trip), incluso il
  caso di file mancante/corrotto.
- La logica di gioco (Penalty/Tournament/Simulator/Persistence) non importa
  SpriteKit/SwiftUI → gira in unit test puri. Audio e Game Center sono iniettati
  come no-op nei test.

## Fuori ambito (v1)

- Monetizzazione (ads / IAP).
- Mini-giochi oltre i rigori (punizioni, palleggi).
- Giocare partite di nazioni diverse dalla propria.
- Modalità "gioca tutte le 104 partite".
- Multiplayer online / risultati reali in tempo reale.

## Note legali

- Usare solo nomi e bandiere delle nazioni e dati di calendario fattuali.
- **Evitare:** loghi/emblemi FIFA, il marchio "FIFA World Cup", mascotte e
  marchi ufficiali del torneo, nomi e somiglianze di calciatori reali.
- Scegliere un nome di prodotto e un'identità visiva originali.
