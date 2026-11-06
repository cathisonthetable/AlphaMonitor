# Alpha Monitor – app di prova per Sony a6100 via USB

Questa prima versione serve a capire **se iOS permette di parlare con la a6100 via cavo**.
Se funziona, avrai già: live view, scatto, ISO / tempo / diaframma.

## Cosa serve
- Cavo **USB‑C → micro‑USB** che trasporti dati (la a6100 ha la porta micro‑USB).
- Un account GitHub gratuito (github.com).
- Sul PC Windows: **Sideloadly** (sideloadly.io) e **iTunes** scaricato dal sito Apple (non dal Microsoft Store).
- Il tuo Apple ID gratuito.

## 1. Compilare l'app in cloud (GitHub)
1. Su github.com → **New repository** → nome `AlphaMonitor` → **Public** (le compilazioni Mac sono gratuite solo per i repo pubblici) → Create.
2. Clicca **uploading an existing file** e trascina dentro: la cartella `Sources`, il file `project.yml` e questo `LEGGIMI.md`. → **Commit changes**.
3. Ora crea il file di compilazione: **Add file → Create new file**, come nome scrivi esattamente
   `.github/workflows/build.yml`
   e incolla il contenuto del file `build.yml` che trovi nella cartella `.github/workflows`. → **Commit changes**.
4. Vai sulla scheda **Actions**: parte "Compila app iOS" (circa 5 minuti).
   - Pallino verde ✅ → apri la compilazione, in fondo trovi **AlphaMonitor-ipa**: scaricalo e scompatta lo zip → ottieni `AlphaMonitor.ipa`.
   - Croce rossa ❌ → scarica **build-log** e mandalo a Claude, che corregge il codice.

## 2. Installare sull'iPhone (da Windows)
1. Collega l'iPhone al PC, apri **Sideloadly**, trascina `AlphaMonitor.ipa`, inserisci il tuo Apple ID → **Start**.
2. Sull'iPhone: **Impostazioni → Generali → VPN e gestione dispositivi** → autorizza il tuo Apple ID.
3. Se richiesto: **Impostazioni → Privacy e sicurezza → Modalità sviluppatore** → attiva e riavvia.
4. Con l'Apple ID gratuito l'app **scade dopo 7 giorni**: basta reinstallarla con Sideloadly.

## 3. Preparare la fotocamera
Sulla a6100: **MENU → (Impostazioni / valigetta) → Connessione USB → PC Remote**.
(Se c'è anche "Impostazioni PC Remote → Dest. salvataggio", scegli "Solo fotocamera".)

## 4. Il test
1. Apri Alpha Monitor e accetta i permessi.
2. Collega la fotocamera all'iPhone con il cavo e accendila.
3. Guarda lo stato in alto:
   - **"Connessa ✓"** → premi **Live view**, prova le frecce di ISO / Tempo / Diaframma (in modo M) e lo scatto.
   - Resta su "Cerco la fotocamera…" o dà errore → premi **Log**, poi l'icona di condivisione, e manda il testo a Claude.

**In ogni caso manda il Log**: anche se funziona, dice quanti fotogrammi al secondo arrivano e che risoluzione ha la live view.
