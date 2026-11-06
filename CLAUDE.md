# Alpha Monitor – riepilogo del progetto

App iOS (SwiftUI) che fa da **monitor e telecomando via cavo USB** per fotocamere Sony Alpha
(provata su **a6100** e **a6400**, iPhone con iOS 26). Parla con la fotocamera in modalità
**PC Remote** usando i comandi PTP Sony tramite `ImageCaptureCore` (`requestSendPTPCommand`).
L'utente scrive in italiano: rispondere in italiano, con istruzioni passo-passo semplici.

## Come si compila e si installa (niente Mac)
- Il progetto Xcode **non è nel repo**: lo genera **XcodeGen** da `project.yml`.
- Ogni push su `main` avvia `.github/workflows/build.yml` (runner macOS): compila senza firma,
  crea `AlphaMonitor.ipa` e lo pubblica come **Release** (tag `build-N`).
- Link fisso all'ultima versione:
  https://github.com/cathisonthetable/AlphaMonitor/releases/latest/download/AlphaMonitor.ipa
- L'utente installa da Windows con **Sideloadly** + Apple ID gratuito (l'app scade ogni 7 giorni).
- Non si può compilare in locale su Windows: verificare la compilazione con
  `gh run watch` / `gh run view --log-failed` dopo il push.
- Ad ogni modifica aggiornare il numero di build nel log di avvio (`CameraController.start()`,
  "build N") così dal Log si capisce quale versione è installata.

## Struttura (Sources/)
- `PTP.swift` – codici operazione/proprietà, contenitori PTP, parser proprietà Sony (0x9209).
- `CameraController.swift` – connessione, handshake, coda comandi seriale, live view, comandi,
  diagnostica nel Log, download foto.
- `LiveViewSurface.swift` – live view: zoom/pan, tocco AF, guide 9:16 · 4:5 · 1:1, griglia, bordo REC, avvisi.
- `CameraScreen.swift` – schermata principale + schermo intero (info ai lati, swipe giù per chiudere).
- `Peaking.swift` – focus peaking con Core Image.
- `SettingsView.swift` – impostazioni (`@AppStorage`): guide, griglia, peaking, specchio, salvataggio foto.
- `PrompterView.swift` – gobbo (teleprompter) con gesture. `ShotListView.swift` – scaletta.
- `PhotoSaver.swift` – salvataggio nel Rullino (Photos).

## Protocollo Sony: cosa abbiamo verificato dai log reali
- Handshake: `0x9201` con 1,0,0 → 2,0,0 → `0x9202` [0xC8] → `0x9201` 3,0,0. Funziona su a6100/a6400.
- Proprietà: `0x9209` restituisce 62 proprietà (contatore u64 + descrittori).
- Live view: `GetObject 0x1009` su handle `0xFFFFC002`, JPEG 1024×576.
  Risposta **0x200F = fotogramma non ancora pronto**: riprovare dopo ~8 ms (con 100 ms si scendeva a 8 fps).
  Risultato: **~25 fps**, trasferimento 5–10 ms.
- Valori: ISO `D21E` (es. 0x280 = 640), tempo `D20D` (num<<16|den), diaframma `5007` (/100),
  modo `500E`, EV `5010`, batteria `D218` (percentuale).
- Comandi "pulsante" con `0x9207`: mezza pressione `D2C1`, scatto `D2C2`, REC `D2C8` (2 = premi, 1 = rilascia).
- **Stato REC: `D21D`** (0 fermo, 1 registra) → l'app si sincronizza anche se il REC parte dalla fotocamera.
- **Foto in attesa di download: `D215`** = 0x8000 | n. Si scaricano con `GetObjectInfo 0x1008` e
  `GetObject 0x1009` sull'handle `0xFFFFC001`, poi vengono salvate in Foto (build 12, da verificare).
- **Spazio sulla scheda: NON disponibile** in PC Remote (Storage ID 0x00010000, nessun contatore
  che cambi dopo gli scatti). Indicatore nascosto.

## Problemi aperti / prossimi passi
1. **Tocco per mettere a fuoco**: i comandi vengono accettati (0x2001) ma lo spot non si sposta.
   `D230` (320,180) è di sola lettura (getset 0). `D2DC` accettato ma senza effetto.
   Build 11 prova `D232` (getset 1, griglia 640×480, x<<16|y): **da verificare col Log** ("Dopo AF").
   Requisito: area AF "Spot flessibile".
2. Verificare il salvataggio automatico delle foto (build 12) e consigliare
   "Dest. salvataggio = PC+Fotocamera" sulla fotocamera.
3. Idee in lista: scheda **Galleria** in modalità MTP (ImageCaptureCore, anteprime + download);
   **audio/forma d'onda** (DJI Mic Mini 2 collegato via jack alla fotocamera: via USB PC Remote
   niente audio → serve HDMI con scheda di acquisizione, oppure prova del trasmettitore in Bluetooth
   diretto all'iPhone); **a6700** (protocollo più recente, possibile streaming USB UVC con audio);
   anteprima **Log → Rec.709** per a6400/a6700 (S-Log); zebra e falsi colori.

## Note pratiche emerse
- Sulla fotocamera: Rete → **Ctrl con smartphone = Disattiv.**, Connessione USB → **PC Remote**,
  **Alimentaz. USB = Disattiv.** (altrimenti la connessione può cadere).
- La a6400 si è scollegata una volta dopo ~20 s (probabile cavo/alimentazione).
