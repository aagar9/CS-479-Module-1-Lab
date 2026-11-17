// ==========================================================================
// TAB: Wearables_ReachGrasp_v7_UI_Preview.pde
// ==========================================================================
// ============================================================================
// REACH-TO-GRASP v7 — v6 commentata + UI PREVIEW senza calibrazione
// ============================================================================
// Guida rapida:
//  1. USER SETTINGS: cambia porte, soglie, tempi, filtri e dimensioni del braccio.
//  2. STATE: variabili aggiornate automaticamente dal programma (NON modificare).
//  3. serialEvent(): ricezione dei campioni da Arduino e calcolo degli angoli.
//  4. CALIBRATIONS: procedure FLEX e MPU, poi correzione del segnale.
//  5. ASSESSMENT / TRAINING: eventi e metriche di ogni reaching.
//  6. GAME: cinematica diretta, target e tracking.
//  7. DRAW: disegno delle schermate, grafici e comandi del mouse.
//  8. STORAGE: salvataggio JSON di calibrazioni e risultati.
// Per navigare in Processing: scheda principale, Sensors, Modes, UI, Controls, Preview.
// Le unita': angoli [gradi], accelerazioni [m/s^2], gyro [rad/s], tempi [ms].

import processing.serial.*;  // importa la libreria per leggere la porta seriale


// ===========================================================================
//                         USER SETTINGS — v7
// ===========================================================================
// Arduino v3 is unchanged. Sensor samples = 25 Hz; graphics = 60 FPS.
// Times are milliseconds unless labelled _S; angles are degrees.

// CONNECTION + DISPLAY
final String PORT = "COM3";  // Nome porta del dispositivo BLE/Arduino che Processing apre.
final int BAUD = 115200;  // Baud rate: deve essere uguale a SERIAL_BAUD in Arduino.
final int UI_FPS = 60;  // Frame richiesti al secondo: riguarda solo la grafica.
final int DATA_TIMEOUT_MS = 1000;  // Dopo questo intervallo senza dati si mostra STREAM LOST.
final boolean USE_VISUAL_SMOOTHING = true;  // true = anima gli angoli dolcemente; false = valori grafici immediati.
final float VISUAL_TAU_MS = 30.0;  // Tempo di risposta del SOLO disegno; non altera angoli e metriche.
final int GRAPH_WINDOW_MS = 5000;  // Ampiezza orizzontale dei due grafici: ultimi 5000 ms.
final int GRAPH_BREAK_MS = 220;  // Interrompe una linea se tra due misure c’e un buco eccessivo.
final int HISTORY = 400;  // Numero massimo di campioni conservati nei grafici circolari.

// UI PREVIEW: apre Assessment, Training e Game anche senza calibrazioni o Arduino.
// In anteprima i dati sono SIMULATI, non vengono usati per misure reali o salvati.
final boolean ALLOW_UI_PREVIEW = true;  // false = torna al vincolo di calibrazione della v6.
final boolean FORCE_UI_PREVIEW = false; // true = usa sempre l'anteprima, anche con sensori pronti.
final int PREVIEW_SAMPLE_MS = 40;       // Campioni simulati: 25 Hz, come Arduino.
final int PREVIEW_REACTION_MS = 450;     // Ritardo fittizio fra GO e inizio reaching.
final int PREVIEW_REACH_MS = 2050;      // Durata fittizia del reaching.
final float PREVIEW_KEY_STEP_DEG = 4;  // Nel Game: gradi per pressione delle frecce.

final float ELBOW_GRAPH_MIN = 0, ELBOW_GRAPH_MAX = 120;  // Limite inferiore fisso del grafico del gomito (gradi).
final float SHOULDER_GRAPH_MIN = -20, SHOULDER_GRAPH_MAX = 130;  // Limite inferiore fisso del grafico della spalla (gradi).
final float ELBOW_TARGET_DEG = 0;  // Linea verde del grafico gomito: estensione completa.
final float SHOULDER_TARGET_DEG = 90;  // Linea verde del grafico spalla: elevazione target.

// FLEX: positioning + holding 0 -> 45 -> 90 -> 120 -> 90 -> 45 -> 0
final int[] FLEX_STEPS = {0,45,90,120,90,45,0};  // Sequenza guidata della calibrazione, compreso il ritorno.
final int[] FLEX_ANGLES = {0,45,90,120};  // Quattro angoli usati per costruire la mappa ADC -> gradi.
final int FLEX_MOVE_MS = 1000, FLEX_HOLD_MS = 5000, FLEX_SETTLE_MS = 800;  // Tempo di transizione; FLEX_HOLD_MS = mantenimento; SETTLE = assestamento.
final int FLEX_MIN_SAMPLES_PER_HOLD = 3;  // Minimo di letture per accettare un mantenimento completo.
final int FLEX_SMOOTH_SAMPLES = 2;  // Media mobile dell’ADC prima della conversione in angolo.
final float FLEX_WARN_SPAN_ADC = 30, FLEX_WARN_STEP_ADC = 5;  // Avvisa se l’escursione ADC totale o tra due pose è troppo piccola.

// MPU calibration: these thresholds exclude gross errors, not small case tilts
final int IMU_CAL_MS = 5000, IMU_MIN_SAMPLES = 30;  // Durata baseline con omero fermo; IMU_MIN_SAMPLES = minimo campioni.
final float IMU_NORM_MIN = 8.0, IMU_NORM_MAX = 11.6;  // Banda accettata per il modulo medio della gravita (m/s^2).
final float IMU_MIN_XY = 5.0;  // Proiezione minima della gravita nel piano X/Y del sensore.
final float IMU_GYRO_SD_MAX = 0.16;  // Massima variabilita combinata delle letture giroscopiche.
final float IMU_ACCEL_SD_MAX = 0.75;  // Massima deviazione standard del modulo accelerometrico.
final float GYRO_THRESHOLD_MIN = 0.12, ACCEL_THRESHOLD_MIN = 0.70;  // Soglie minime del riconoscimento motion/still.
final float GYRO_NOISE_MULT = 4.0, ACCEL_NOISE_MULT = 4.0;  // Soglie adattate al rumore misurato in calibrazione.
float gyroSign = -1.0;  // Segno del gyro Z: cambia solo se i versi ACC/GYRO sono opposti.

// Complementary filter: stable across sample-rate variations
final float FUSION_TAU_STILL_S = 0.27;  // Costante di tempo (secondi) del complementare quando fermo.
final float FUSION_TAU_MOVING_S = 13.3;  // Costante di tempo quando in moto: maggiore affidamento al gyro.
final float MAX_GYRO_DT_S = 0.18;  // Se un intervallo tra pacchetti e troppo lungo, non integra il gyro.
// Slow gyro-offset tracking only during confirmed prolonged stillness
final boolean AUTO_GYRO_BIAS = true;  // Permette un lentissimo aggiornamento dell’offset a riposo.
final float AUTO_GYRO_BIAS_TAU_S = 45;  // Costante di tempo dell’aggiornamento offset, in secondi.
final int BIAS_STILL_MS = 2000;  // Tempo necessario a dichiarare il sensore stabile per adattare il bias.
final float BIAS_GYRO_LIMIT = 0.075;  // Condizioni moderate per aggiornare il bias senza corromperlo.
final float BIAS_ACCEL_LIMIT = 0.50;  // Limite sulla differenza tra accelerazione e gravita a riposo.
final float BIAS_ACCEL_ANGLE_DRIFT_LIMIT_DEG = 1.8;  // Sospende adattamento se l’angolo ACC cambia molto.

// Arduino restart detection: never discard calibration for one odd CSV line
final int RESET_BACKJUMP_MS = 2000, RESET_CONFIRM_SAMPLES = 3;  // Sospetta reboot solo se il timestamp arretra di oltre 2 secondi.
final int RESET_MAX_STEP_MS = 500;  // Intervallo massimo tra timestamp usati per confermare reboot.

// MOTION recognition: gyro OR deviation of acceleration modulus
final int MOTION_SMOOTH_SAMPLES = 3;  // Numero di misure recenti per soglie gyro/accelerazione.
final int ON_CONFIRM_MS = 200, OFF_CONFIRM_MS = 400;  // Durata per confermare inizio movimento; OFF per la fine.
final int MIN_REACH_MS = 200;  // Scarta movimenti troppo brevi; ROM minimo valido richiesto.
final float MIN_REACH_ROM_DEG = 4;  // ROM minimo di spalla O gomito per accettare un reaching.
final int MAX_TRIAL_MS = 14000;  // Timeout di sicurezza in caso di mancato raggiungimento.

// FSR — OFF until sensors are installed. Raw ADC values, NOT Newtons.
final boolean FSR_ENABLED = false;  // false finche i sensori di forza non sono collegati.
final int FSR_CONTACT_ADC = 100;  // Soglia ADC per dichiarare il primo contatto.
final int FSR_TARGET_MIN_ADC = 220, FSR_TARGET_MAX_ADC = 700;  // Range ADC della presa desiderata: pollice e indice insieme.
final int FSR_CONTACT_CONFIRM_MS = 120;  // Conferma contatto dopo questo tempo continuo sopra soglia.
final int GRASP_HOLD_MS = 3000;  // Tempo di presa consecutiva nella fascia target.
final int GRASP_TIMEOUT_MS = 12000;  // Scadenza della fase GRASP prima di proporre RETRY.

// ASSESSMENT
final int ASSESSMENT_TRIALS = 5;  // Numero di raggiungimenti nell’Assessment.
final int COUNTDOWN_MS = 3000;  // Durata iniziale del conto alla rovescia (millisecondi).

// TRAINING
final int TRAINING_TRIALS = 10;  // Numero di reaching del Training.
final float TRAIN_INITIAL_MARGIN = 1.10;  // Tempo target iniziale come multiplo della media Assessment.
final float TRAIN_MANUAL_TARGET_S = 2.5;  // Tempo usato quando manca un Assessment salvato.
final int TRAIN_ADAPT_EVERY = 2;  // Aggiorna la difficolta ogni N trial completati.
final float TRAIN_ADAPT_FRACTION = 0.05;  // Variazione percentuale del target (0.05 = 5%).
final float TRAIN_ON_TIME_TOLERANCE = 0.15;  // Tolleranza relativa +/- intorno al tempo target.
final float TRAIN_MIN_TARGET_S = 0.8, TRAIN_MAX_TARGET_S = 7.0;  // Limiti minimo e massimo del tempo assegnato nel Training.
final float TRAIN_MIN_ROM_FRACTION = 0.75;  // ROM richiesta, come quota della media Assessment.

// GAME — arm dimensions in meters, adjustable for each user
final float UPPER_ARM_M = 0.31, FOREARM_M = 0.27;  // Lunghezza omero e avambraccio del modello per il gioco [m].
final boolean GAME_USE_ASSESSMENT_ROM = true;  // Limita i target ai ROM osservati nell’ultimo Assessment.
final float GAME_SHOULDER_MIN_DEG = 0, GAME_SHOULDER_MAX_DEG = 85;  // ROM di spalla consentito per generare le posizioni.
final float GAME_ELBOW_MIN_DEG = 10, GAME_ELBOW_MAX_DEG = 115;  // ROM di gomito consentito per generare le posizioni.
final int GAME_STATIC_COUNT = 6;  // Numero di palline fisse nel gioco (6 posizioni predefinite).
final int GAME_STATIC_HOLD_MS = 200;  // Tempo minimo di sovrapposizione mano-pallina.
final int GAME_BETWEEN_TARGET_MS = 350;  // Breve pausa tra un target fisso e il successivo.
final int GAME_STATIC_TIMEOUT_MS = 12000;  // Tempo disponibile per ciascun target statico.
final int GAME_TRACK_MS = 6500;  // Durata di ciascuna delle due traiettorie mobili.
final float GAME_TARGET_RADIUS_M = 0.032;  // Raggio della pallina; con il raggio mano basta sovrapposizione.
final float GAME_HAND_RADIUS_M = 0.022;  // Raggio virtuale del polso/mano per il rilevamento.
final float GAME_TRACK_DISTANCE_M = 0.09;  // Lunghezza iniziale del percorso mobile; riducibile se serve.

// CALIBRATION FILE — retained across Processing restarts (same physical mounting!)
final String CALIBRATION_FILE = "reach_grasp_calibration.json";  // Nome del JSON salvato accanto al progetto Processing.
// ===========================================================================

// PAGINE: valori interni per scegliere quale schermata disegnare.
final int HOME=0, FLEX=1, IMU=2, LIVE=3, ASSESS=4, TRAIN=5, GAME=6;
// FASI DEL TRIAL: non sono schermate diverse, ma stati della stessa UI.
final int READY=0, COUNTDOWN=1, WAIT_START=2, REACH=3, GRASP=4,
          COMPLETE=5, RESULTS=6, FAILED=7;
// FASI DEL GIOCO: preparazione, target, tracking, risultati.
final int GAME_READY=0, GAME_STATIC=1, GAME_TRACK=2, GAME_RESULTS=3;

// OGGETTO SERIAL: gestisce la connessione BLE tramite COM3.
Serial port;
// STATO DEL PROGRAMMA: connessione, pagina attuale e messaggio informativo.
boolean portOK=false;
int page=HOME;
// Messaggio mostrato nella schermata HOME.
String notice="Calibrate FLEX and MPU; calibrations are stored locally.";

// Raw samples + BLE diagnostic
// TIMESTAMP ARDUINO: ultimo tempo ricevuto, precedente e candidato reset.
long sensorMs=0, previousImuMs=-1, lastResetCandidateMs=-1;
// DIAGNOSTICA: ora ricezione, contatori reset e timestamp scartati.
int lastHostMs=-100000, resetCandidateCount=0, arduinoRestarts=0, badTimestamps=0;
// DATI GREZZI: tre letture ADC provenienti dal firmware.
int flexADC=0, thumbADC=0, indexADC=0;
// MPU RAW: 3 accelerazioni [m/s^2] e 3 velocita angolari [rad/s].
float ax=0,ay=0,az=0,gx=0,gy=0,gz=0;
// Flag validita MPU e flag sincronizzazione dopo possibile reboot.
boolean mpuValid=false, imuResyncPending=false;
// RX: campioni ricevuti in un secondo e frequenza stimata.
int rxStartMs=0, rxCount=0;
float rxHz=0;
// BACKLOG: ritardo relativo della coda dati rispetto al piu rapido pacchetto.
long minHostOffset=Long.MAX_VALUE, backlogMs=0;

// Flex calibration; every COMPLETED hold contributes ONE average per angle
// FLEX CAL: fase MOVE/HOLD, posizione, inizio fase e cicli completati.
int flexPhase=0, flexStep=0, flexPhaseStarted=0, fullFlexCycles=0;
// Somma ADC del mantenimento corrente, dopo il tempo di assestamento.
float flexHoldSum=0;
// Numero campioni del mantenimento corrente.
int flexHoldN=0;
// Somma delle MEDIE dei singoli mantenimenti e 4 punti di calibrazione.
float[] flexPoseSum=new float[4], flexAnchors=new float[4];
// Quanti mantenimenti COMPLETATI per ogni angolo.
int[] flexPoseHolds=new int[4];
// Flag calibrazione flex disponibile.
boolean flexReady=false;
// Angolo reale stimato del gomito [gradi], non grafico.
float elbowDeg=Float.NaN;
// Buffer circolare della media mobile flex.
float[] flexSmooth=new float[Math.max(1,FLEX_SMOOTH_SAMPLES)];
// Indice di scrittura e numero letture valide nel buffer.
int flexSmoothIndex=0, flexSmoothCount=0;

// MPU calibration and diagnostic statistics
// MPU CAL: fase 0=ready,1=raccolta,2=risultati; campioni.
int imuPhase=0, imuStarted=0, imuN=0;
// Somme e somme dei quadrati per medie/varianze ACC e GYRO.
float sx=0,sy=0,sz=0,sgx=0,sgy=0,sgz=0,sqgx=0,sqgy=0,sqgz=0,sNorm=0,sqNorm=0;
// Calibrazione MPU valida e successo dell’ultimo tentativo.
boolean imuReady=false, imuCalSuccess=false;
// Offset gyro X/Y/Z e riferimento angolare gravita alla posa iniziale.
float biasX=0,biasY=0,biasZ=0,accelZeroDeg=0,gravityRef=9.81;
// Soglie empiriche ricavate dal rumore della baseline.
float gyroThreshold=GYRO_THRESHOLD_MIN, accelThreshold=ACCEL_THRESHOLD_MIN;
// Angoli ACC, solo GYRO e fusione complementare [gradi].
float thetaAccel=Float.NaN, thetaGyro=Float.NaN, thetaFused=Float.NaN;
// Modulo velocita angolare corretta e deviazione dal modulo g.
float omegaMag=0, accelDev=0;
// Campioni dell’ultimo tentativo: mostrati nella diagnostica.
int imuSamplesLast=0;
// Statistiche dell’ultimo tentativo, usate per PASS/FAIL.
float imuLastNorm=Float.NaN, imuLastXY=Float.NaN, imuLastGyroSD=Float.NaN,
      imuLastAccelSD=Float.NaN;
// Motivo/i esatti del fallimento della baseline MPU.
String imuFailure="Not calibrated";
// Inizio fase davvero ferma per adattare lentamente bias gyro.
long biasStillFrom=-1;
// Angolo di partenza del periodo fermo: protegge da deriva lenta.
float biasAngleStart=0;

// Motion recognition and event history
// Buffer per media mobile del riconoscimento movimento.
float[] gyroWindow=new float[Math.max(1,MOTION_SMOOTH_SAMPLES)];
// Secondo buffer per la deviazione di accelerazione.
float[] accelWindow=new float[Math.max(1,MOTION_SMOOTH_SAMPLES)];
// Numero di punti nel buffer e prossima posizione di scrittura.
int motionWindowN=0, motionWindowI=0;
// Stato corrente riconosciuto (in movimento / fermo).
boolean inMotion=false;
// Tempi delle condizioni da confermare, inizio e fine reali.
long onsetCandidate=-1, offCandidate=-1, motionStart=-1, stillStart=-1;
// Durate dell’ultimo moto e dell’ultimo intervallo fermo.
long lastMotionMs=-1, lastStillMs=-1;
// Numero di movimenti riconosciuti dal LIVE monitor.
int motionCount=0;
// Eventi validi per un singolo campione, usati dai trial.
boolean movementStartedEvent=false, movementEndedEvent=false;
// Timestamp retrodatati degli eventi riconosciuti.
long eventOnset=-1, eventOffset=-1;

// Plot history: measured (not graphically smoothed) joint angles
// STORIA GRAFICI: timestamp degli ultimi HISTORY campioni.
long[] plotT=new long[HISTORY];
// Buffer angoli misurati (non smoothing grafico).
float[] plotElbow=new float[HISTORY], plotShoulder=new float[HISTORY];
// Indice prossimo slot, numero campioni conservati.
int plotHead=0, plotN=0;
// Angoli SOLO DISEGNO: gli algoritmi usano elbowDeg/thetaFused.
float displayElbow=Float.NaN,displayShoulder=Float.NaN;
// Tempo dell’ultimo frame per filtro grafico indipendente dai FPS.
int lastDisplayMs=0;

// UI PREVIEW: dati fittizi usati SOLTANTO quando si entra in una modalita senza sensori.
boolean uiPreview=false;
int previewLastSample=-100000;
boolean previewOnsetSent=false, previewEndSent=false;
float previewGameShoulder=35, previewGameElbow=70;
// Salviamo la stima reale prima di mostrare gli angoli simulati, poi la ripristiniamo.
long realSensorMsBeforePreview=0;
float realElbowBeforePreview=Float.NaN, realAccelBeforePreview=Float.NaN;
float realGyroBeforePreview=Float.NaN, realFusedBeforePreview=Float.NaN;

// Assessment / training one-screen state machine
// TRIAL: fase, partenza countdown e fine reaching lato Processing.
int trialPhase=READY, countdownStarted=0, trialEndHost=0;
// Orari GO e contatto; combinazione orologio Arduino / Processing.
long trialGoSensor=0, trialGoHost=0, contactCandidate=-1;
// Timestamp della presa valida iniziata (richiede 3 s consecutivi).
long graspStarted=-1;
// Angoli iniziali del singolo trial per il calcolo delle escursioni.
float baselineShoulder=Float.NaN, baselineElbow=Float.NaN;
// Minimo gomito e massimo spalla durante il trial.
float minElbow=Float.POSITIVE_INFINITY,maxShoulder=Float.NEGATIVE_INFINITY;
// Inizio/fine reaching riconosciuti dal detector.
long reachStart=-1, reachEnd=-1;
// Testo ON TIME / TOO EARLY / TOO SLOW / RETRY.
String trialFeedback="";
// Tempo target attuale del Training [s].
float trainTargetS=TRAIN_MANUAL_TARGET_S;
// Risultati della sessione Assessment attualmente aperta.
ArrayList<Trial> assessment=new ArrayList<Trial>();
// Ultimo Assessment completo: riferimento per Training e Game.
ArrayList<Trial> completedAssessment=new ArrayList<Trial>(); // latest FINISHED session
// Risultati della sessione Training attualmente aperta.
ArrayList<Trial> training=new ArrayList<Trial>();

// Game: target coordinates in meters from shoulder; y is positive DOWN
// GAME: fase e indici dei target statici/mobili.
int gamePhase=GAME_READY,gameStaticIndex=0,gameTrackIndex=0;
// Tempi Processing per durata target e comparsa pallina.
int gamePhaseHost=0,gameTargetHost=0;
// Inizio del contatto virtuale continuo mano-pallina.
long gameOverlapFrom=-1;
float gameShMin,gameShMax,gameElMin,gameElMax;
// Coordinate dei sei target statici nel piano sagittale [m].
float[] gameX=new float[GAME_STATIC_COUNT],gameY=new float[GAME_STATIC_COUNT];
// Due traiettorie: coordinate 2D di inizio e fine [m].
float[][] trackStart=new float[2][2], trackEnd=new float[2][2];
// Accumulatori errore e tempo di inseguimento.
float trackDistanceSum=0,trackOnTimeMs=0,trackTotalTimeMs=0;
// Campioni del tracking e successi statici.
int trackN=0, gameHits=0;
// Tempi response dei target fissi [s].
float[] staticResponse=new float[GAME_STATIC_COUNT];
// 1=target raggiunto, 0=timeout.
int[] staticSucceeded=new int[GAME_STATIC_COUNT];
// Timestamp precedente per time-on-target sui veri campioni.
long previousTrackSensor=-1;

// CLASS: raccoglie tutte le metriche di UNA ripetizione.
// ArrayList<Trial> e una lista dinamica che cresce ad ogni trial completato.
class Trial {
  float reactionS, movementS, initialShoulder, initialElbow; // tempi [s], angoli iniziali [gradi]
  float shoulderMaximum, shoulderExcursion, elbowMinimum, elbowExtension; // estremi e ROM [gradi]
  float graspS, targetS; // tempo fino alla presa stabile e tempo assegnato [s]
  boolean graspValid; // true se i due FSR hanno completato GRASP_HOLD_MS
  String feedback; // esito della prova (ON TIME / TOO SLOW ecc.)
  // COSTRUTTORE: salva i valori appena misurati nella struttura Trial.
  Trial(float reaction, float move, float s0, float e0,
        float sMax, float sROM, float eMin, float eROM, float grip,
        boolean gripOK, float target, String outcome) {
    reactionS=reaction; movementS=move; initialShoulder=s0; initialElbow=e0;
    shoulderMaximum=sMax; shoulderExcursion=sROM; elbowMinimum=eMin;
    elbowExtension=eROM; graspS=grip; graspValid=gripOK;
    targetS=target; feedback=outcome;
  }
}

// ---------------------------------------------------------------------------
// INIZIALIZZAZIONE — eseguita una sola volta.
// Crea la finestra, carica i JSON e apre la COM; try/catch impedisce un crash se COM3 e occupata.
void setup() {
  size(1300,820);                          // dimensioni della finestra Processing in pixel
  frameRate(UI_FPS);                      // FPS richiesti, indipendenti dai 25 Hz Arduino
  smooth(4);                             // anti-aliasing: linee/cerchi meno seghettati
  loadCalibration();
  loadAssessmentResults();
  try {
    port=new Serial(this,PORT,BAUD);     // this = sketch Processing corrente
    port.clear();                         // elimina eventuali byte vecchi all'apertura
    port.bufferUntil('\n');             // serialEvent() scattera a ogni fine riga
    portOK=true;
  } catch(Exception ex) {
    portOK=false;
    notice="Cannot open "+PORT+". Close Arduino Serial Monitor and check connection.";
  }
}

// ---------------------------------------------------------------------------
// La ricezione e "fresca" se l’ultimo pacchetto e piu recente di DATA_TIMEOUT_MS.
boolean fresh() { return portOK && millis()-lastHostMs<DATA_TIMEOUT_MS; }
// ---------------------------------------------------------------------------
// I trial richiedono flusso presente, due calibrazioni e MPU sincronizzata.
boolean readySensors() { return fresh() && flexReady && imuReady && mpuValid && !imuResyncPending; }
// ---------------------------------------------------------------------------
// Converte numero in stringa; NaN/Inf diventano "--" invece di un valore fittizio.
String v(float n,int decimals) { return Float.isNaN(n)||Float.isInfinite(n)?"--":nf(n,0,decimals); }
// ---------------------------------------------------------------------------
// Formatta una durata espressa in secondi.
String sec(float s) { return Float.isNaN(s)?"--":v(s,2)+" s"; }
// ---------------------------------------------------------------------------
// Converte millisecondi in secondi solo per la scritta visualizzata.
String ms(long t) { return t<0?"--":sec(t/1000.0); }
// ---------------------------------------------------------------------------
// Riporta un angolo nell’intervallo [-180°,180°] per evitare salti a +/-180°.
float wrap(float deg) { while(deg>180)deg-=360; while(deg< -180)deg+=360; return deg; }
// ---------------------------------------------------------------------------
// Trova l’indice di una posa flex nella sequenza delle 4 calibrazioni.
int angleIndex(int a) { for(int i=0;i<4;i++)if(FLEX_ANGLES[i]==a)return i; return -1; }



// ==========================================================================
// TAB: Sensors.pde
// ==========================================================================
// CSV protocol: timestamp, flex, thumb, index, accel xyz, gyro xyz, MPU valid
// ---------------------------------------------------------------------------
// ACQUISIZIONE — Processing chiama questa funzione a ogni riga CSV ricevuta.
// Converte i dati, scarta righe difettose, aggiorna angoli, grafici e modalità attiva.
void serialEvent(Serial serial) {
  String s=serial.readStringUntil('\n'); // legge UNA riga CSV intera
  if(s==null)return;
  if(uiPreview)return; // Il flusso reale non deve alterare i dati simulati della UI.
  String[] c=split(trim(s),',');          // trim: spazi/newline; split: divide sui campi virgola
  if(c.length!=11)return;
  try {
    long t=Long.parseLong(c[0]);          // timestamp Arduino [ms] (long = intero a 64 bit)
    int f=Integer.parseInt(c[1]),thumb=Integer.parseInt(c[2]),index=Integer.parseInt(c[3]); // ADC 0..1023
    float x=Float.parseFloat(c[4]),y=Float.parseFloat(c[5]),z=Float.parseFloat(c[6]);
    float wx=Float.parseFloat(c[7]),wy=Float.parseFloat(c[8]),wz=Float.parseFloat(c[9]);
    boolean valid=Integer.parseInt(c[10])==1; // 1 = MPU valido, 0 = lettura non disponibile
    if(t<0 || Float.isNaN(x) || Float.isNaN(y) || Float.isNaN(z) ||
       Float.isNaN(wx) || Float.isNaN(wy) || Float.isNaN(wz) ||
       f<0 || f>1023 || thumb<0 || thumb>1023 || index<0 || index>1023)return;

    // PROTEZIONE RESTART: un singolo timestamp errato NON cambia imuReady.
    // Tre timestamp nuovi e crescenti confermano un possibile reboot del contatore.
    // Timestamp vecchi scartati: niente integrazione di campioni fuori ordine.
    // Timestamp out of order is never sufficient to delete a calibration.
    if(sensorMs!=0 && t<=sensorMs) {
      if(sensorMs-t<=RESET_BACKJUMP_MS) {
        badTimestamps++; resetCandidateCount=0; return;
      }
      if(resetCandidateCount==0 || t<=lastResetCandidateMs ||
         t-lastResetCandidateMs>RESET_MAX_STEP_MS)resetCandidateCount=1;
      else resetCandidateCount++;
      lastResetCandidateMs=t;
      if(resetCandidateCount<RESET_CONFIRM_SAMPLES)return;
      arduinoRestarts++;
      resetCandidateCount=0;
      previousImuMs=-1;
      imuResyncPending=imuReady;
      minHostOffset=Long.MAX_VALUE;
      rxStartMs=0; rxCount=0;
      plotHead=0; plotN=0;
      resetMotion();
      if(page==IMU && imuPhase==1)resetImuAccumulator();
      notice="Arduino clock restarted: calibration retained. Keep arm still to re-sync.";
    } else {
      if(resetCandidateCount>0)badTimestamps+=resetCandidateCount;
      resetCandidateCount=0;
    }

    sensorMs=t;flexADC=f;thumbADC=thumb;indexADC=index;
    ax=x;ay=y;az=z;gx=wx;gy=wy;gz=wz;mpuValid=valid;
    lastHostMs=millis();
    if(rxStartMs==0)rxStartMs=lastHostMs;
    rxCount++;
    if(lastHostMs-rxStartMs>=1000) {
      rxHz=1000.0*rxCount/(lastHostMs-rxStartMs);
      rxCount=0;rxStartMs=lastHostMs;
    }
    long offset=(long)lastHostMs-t;       // differenza tra clock Processing e timestamp Arduino
    if(offset<minHostOffset)minHostOffset=offset; // riferimento al ritardo migliore osservato
    backlogMs=Math.max(0,offset-minHostOffset); // ritardo RELATIVO, non latenza assoluta

    // BUFFER FLEX: salva i piu recenti ADC e ne calcola la media mobile.
    // Solo questa media entra nella conversione angolo -> gomito.
    flexSmooth[flexSmoothIndex]=flexADC;
    flexSmoothIndex=(flexSmoothIndex+1)%flexSmooth.length;
    flexSmoothCount=Math.min(flexSmooth.length,flexSmoothCount+1);
    float mean=0;
    for(int i=0;i<flexSmoothCount;i++)mean+=flexSmooth[i];
    mean/=flexSmoothCount;
    if(flexReady) {
      elbowDeg=flexToDeg(mean);
    }

    // Calibrate only during stable portion of each FULLY COMPLETED hold.
    // CALIBRAZIONE FLEX: campioni solo dopo l’assestamento in fase HOLD.
    if(page==FLEX && flexPhase==2 && millis()-flexPhaseStarted>=FLEX_SETTLE_MS) {
      flexHoldSum+=flexADC; flexHoldN++;
    }
    // BASELINE MPU: somme E[x] ed E[x²] per calcolare rumore e medie.
    if(page==IMU && imuPhase==1 && valid) {
      imuN++;sx+=ax;sy+=ay;sz+=az;
      sgx+=gx;sgy+=gy;sgz+=gz;
      sqgx+=gx*gx;sqgy+=gy*gy;sqgz+=gz*gz;
      float norm=sqrt(ax*ax+ay*ay+az*az);
      sNorm+=norm;sqNorm+=norm*norm;
    }
    // STIMA: prima fusione angoli, poi detector degli eventi di movimento.
    if(imuReady && valid)updateOrientation(t);
    if(imuReady && valid)updateMotion(t);

    // GRAFICI: ring buffer con timestamp Arduino e angoli NON filtrati graficamente.
    plotT[plotHead]=t;
    plotElbow[plotHead]=flexReady?elbowDeg:Float.NaN;
    plotShoulder[plotHead]=imuReady?thetaFused:Float.NaN;
    plotHead=(plotHead+1)%HISTORY;
    plotN=Math.min(HISTORY,plotN+1);

    // L’algoritmo delle modalita riceve esattamente i campioni che riceve la GUI.
    if(page==ASSESS || page==TRAIN)onTrialSample(t);
    if(page==GAME)onGameSample(t);
  } catch(Exception ex) {
    // try/catch: se una conversione CSV fallisce, ignora SOLO questa riga.
    // Nessun blocco del programma, nessuna perdita di calibrazione.
  }
}

// ==========================================================================
// CALIBRATIONS
// ==========================================================================
// ---------------------------------------------------------------------------
// Azzera i soli accumulatori del nuovo tentativo flex, senza cancellare i punti gia validi.
void startFlex() {
  flexPhase=1;flexStep=0;fullFlexCycles=0;flexPhaseStarted=millis();
  flexHoldSum=0;flexHoldN=0;
  for(int i=0;i<4;i++){flexPoseSum[i]=0;flexPoseHolds[i]=0;}
  notice="Flex calibration running. STOP will use completed holds only.";
}
// ---------------------------------------------------------------------------
// Ciclo MOVE -> HOLD: conta SOLO il mantenimento completato.
// La media di ogni HOLD pesa una volta, anche se ha piu campioni.
void tickFlex() {
  if(flexPhase==0)return;
  if(flexPhase==1 && millis()-flexPhaseStarted>=FLEX_MOVE_MS) {
    flexPhase=2;flexPhaseStarted=millis();flexHoldSum=0;flexHoldN=0;
  } else if(flexPhase==2 && millis()-flexPhaseStarted>=FLEX_HOLD_MS) {
    // Treat every complete 5-second hold equally, irrespective of sample count.
    int k=angleIndex(FLEX_STEPS[flexStep]);
    if(k>=0 && flexHoldN>=FLEX_MIN_SAMPLES_PER_HOLD) {
      flexPoseSum[k]+=flexHoldSum/flexHoldN;
      flexPoseHolds[k]++;
    }
    flexHoldN=0;flexHoldSum=0;
    flexStep++;
    if(flexStep>=FLEX_STEPS.length) {flexStep=0;fullFlexCycles++;}
    flexPhase=1;flexPhaseStarted=millis();
  }
}
// ---------------------------------------------------------------------------
// Verifica le 4 pose, il loro ordinamento ADC e salva la calibrazione se valida.
// Un tentativo fallito NON sovrascrive la calibrazione precedente.
void stopFlex() {
  flexPhase=0;
  String missing="";
  for(int i=0;i<4;i++)if(flexPoseHolds[i]==0)missing+=FLEX_ANGLES[i]+"° ";
  if(missing.length()>0) {
    notice="FLEX NOT SAVED: complete a HOLD at "+missing+". Old calibration retained.";
    page=HOME;return;
  }
  float[] a=new float[4]; // array temporaneo dei 4 riferimenti, prima di validarli
  for(int i=0;i<4;i++)a[i]=flexPoseSum[i]/flexPoseHolds[i];
  float dir=a[3]>=a[0]?1:-1,smallest=Float.POSITIVE_INFINITY; // ?: sceglie il verso ADC crescente/decrescente
  for(int i=0;i<3;i++) {
    float gap=dir*(a[i+1]-a[i]);
    if(gap<=0) {
      notice="FLEX NOT SAVED: nonmonotonic means (0/45/90/120): "+
        v(a[0],1)+"/"+v(a[1],1)+"/"+v(a[2],1)+"/"+v(a[3],1);
      page=HOME;return;
    }
    smallest=min(smallest,gap);
  }
  arrayCopy(a,flexAnchors);                // copia i 4 nuovi riferimenti nella calibrazione attiva
  flexReady=true;
  flexSmoothCount=0;
  elbowDeg=flexToDeg(flexADC);
  float span=abs(a[3]-a[0]);
  notice="FLEX CALIBRATED: "+fullFlexCycles+" cycles; "+sumInt(flexPoseHolds)+" completed holds."
    +(span<FLEX_WARN_SPAN_ADC||smallest<FLEX_WARN_STEP_ADC?" Low ADC sensitivity: check mounting.":"");
  saveCalibration();page=HOME;
}
// ---------------------------------------------------------------------------
// Somma il numero di mantenimenti completi di tutte le pose.
int sumInt(int[] arr) {int n=0;for(int i=0;i<arr.length;i++)n+=arr[i];return n;}
// ---------------------------------------------------------------------------
// CALIBRAZIONE MULTIPUNTO: conversione ADC -> angolo via interpolazione lineare.
// Agli estremi si limita la stima a 0° e 120°: niente estrapolazione incerta.
float flexToDeg(float adc) {
  if(!flexReady)return Float.NaN;
  float d=flexAnchors[3]>flexAnchors[0]?1:-1;
  if(d*(adc-flexAnchors[0])<=0)return 0;
  if(d*(adc-flexAnchors[3])>=0)return 120;
  for(int i=0;i<3;i++)if(d*(adc-flexAnchors[i])>=0 && d*(adc-flexAnchors[i+1])<=0) {
    return lerp(FLEX_ANGLES[i],FLEX_ANGLES[i+1], // lerp(a,b,f): a+(b-a)*f
                (adc-flexAnchors[i])/(flexAnchors[i+1]-flexAnchors[i]));
  }
  return Float.NaN;
}
// ---------------------------------------------------------------------------
// Riparte una nuova acquisizione MPU di riferimento senza cancellare la vecchia baseline.
void resetImuAccumulator() {
  imuStarted=millis();imuN=0;
  sx=sy=sz=sgx=sgy=sgz=sqgx=sqgy=sqgz=sNorm=sqNorm=0;
}
// ---------------------------------------------------------------------------
// Avvia la calibrazione MPU: tieni omero verticale e fermo 5 s.
void startImu() {
  imuPhase=1;imuCalSuccess=false;resetImuAccumulator();
  imuFailure="";
  notice="Keep the arm down and still for 5 seconds.";
}
// ---------------------------------------------------------------------------
// Calcola medie e deviazioni standard del gyro e dell’accelerazione.
// Le soglie accettano inclinazioni moderate della case; mostra i motivi reali di FAIL.
void finishImu() {
  imuPhase=2;
  imuSamplesLast=imuN;
  if(imuN==0) {
    imuFailure="No valid MPU samples";imuCalSuccess=false;
    notice="MPU CALIBRATION FAILED: "+imuFailure+". Previous baseline retained.";
    return;
  }
  float mx=sx/imuN,my=sy/imuN,mz=sz/imuN;
  float mgx=sgx/imuN,mgy=sgy/imuN,mgz=sgz/imuN;
  imuLastNorm=sNorm/imuN;
  imuLastAccelSD=sqrt(max(0,sqNorm/imuN-imuLastNorm*imuLastNorm)); // SD = sqrt(E[x^2]-E[x]^2)
  imuLastGyroSD=sqrt(max(0,sqgx/imuN-mgx*mgx)+max(0,sqgy/imuN-mgy*mgy)+
                       max(0,sqgz/imuN-mgz*mgz));
  imuLastXY=sqrt(mx*mx+my*my);
  // CHECK MPU: ogni criterio fallito viene elencato (non piu un generico "unstable").
  String fail="";
  if(imuN<IMU_MIN_SAMPLES)fail+="TOO FEW SAMPLES; ";
  if(imuLastNorm<IMU_NORM_MIN || imuLastNorm>IMU_NORM_MAX)fail+="GRAVITY NORM; ";
  if(imuLastXY<IMU_MIN_XY)fail+="SENSOR PLANE; ";
  if(imuLastGyroSD>IMU_GYRO_SD_MAX)fail+="GYRO UNSTABLE; ";
  if(imuLastAccelSD>IMU_ACCEL_SD_MAX)fail+="ACC UNSTABLE; ";
  imuFailure=fail.length()==0?"None":fail;
  if(fail.length()>0) {
    imuCalSuccess=false;
    notice="MPU FAILED: "+imuFailure+" Previous calibration retained.";
    return;
  }
  biasX=mgx;biasY=mgy;biasZ=mgz;
  // Zero dal vettore gravitazionale medio nella posa anatomica iniziale.
  // Non si azzera durante il raggiungimento dell’oggetto.
  gravityRef=imuLastNorm;
  accelZeroDeg=degrees(atan2(mx,-my));   // atan2: angolo nel piano XY del sensore, con segni corretti
  gyroThreshold=max(GYRO_THRESHOLD_MIN,GYRO_NOISE_MULT*imuLastGyroSD);
  accelThreshold=max(ACCEL_THRESHOLD_MIN,ACCEL_NOISE_MULT*imuLastAccelSD);
  thetaFused=thetaAccel=thetaGyro=0;
  previousImuMs=-1;
  imuResyncPending=false;
  biasStillFrom=-1;
  imuReady=true;imuCalSuccess=true;
  imuFailure="None";
  notice="MPU CALIBRATED: reference and gyro offset saved.";
  saveCalibration();
}

// ---------------------------------------------------------------------------
// JSON CALIBRATION: memorizza i 4 ADC, zero MPU, bias gyro e soglie.
// try/catch intercetta mancanza di permessi o errori di scrittura.
void saveCalibration() {
  JSONObject j=new JSONObject();
  j.setInt("version",5);               // permette di rifiutare vecchi file incompatibili
  j.setBoolean("flexReady",flexReady);
  j.setBoolean("imuReady",imuReady);
  for(int i=0;i<4;i++)j.setFloat("flex"+i,flexAnchors[i]);
  j.setFloat("biasX",biasX);j.setFloat("biasY",biasY);j.setFloat("biasZ",biasZ);
  j.setFloat("accelZeroDeg",accelZeroDeg);j.setFloat("gravityRef",gravityRef);
  j.setFloat("gyroThreshold",gyroThreshold);j.setFloat("accelThreshold",accelThreshold);
  j.setFloat("gyroSign",gyroSign);
  try {saveJSONObject(j,sketchPath(CALIBRATION_FILE));} // JSON scritto nella cartella dello sketch
  catch(Exception e) {notice="Could not save calibration file: "+e.getMessage();}
}
// ---------------------------------------------------------------------------
// Carica la baseline precedente soltanto se il file esiste e la versione e compatibile.
// Ricalibrare se la fascia o la case sono state spostate sul corpo.
void loadCalibration() {
  java.io.File f=new java.io.File(sketchPath(CALIBRATION_FILE)); // percorso assoluto nel computer
  if(!f.exists())return;
  try {
    JSONObject j=loadJSONObject(f.getAbsolutePath());  // lettura dati salvati dal disco
    if(j==null || j.getInt("version")!=5)return;
    boolean newFlex=j.getBoolean("flexReady"),newImu=j.getBoolean("imuReady");
    float[] a=new float[4];
    for(int i=0;i<4;i++)a[i]=j.getFloat("flex"+i);
    boolean monotonic=(a[0]<a[1] && a[1]<a[2] && a[2]<a[3]) ||
                       (a[0]>a[1] && a[1]>a[2] && a[2]>a[3]);
    if(newFlex && monotonic) {arrayCopy(a,flexAnchors);flexReady=true;}
    if(newImu) {
      biasX=j.getFloat("biasX");biasY=j.getFloat("biasY");biasZ=j.getFloat("biasZ");
      accelZeroDeg=j.getFloat("accelZeroDeg");gravityRef=j.getFloat("gravityRef");
      gyroThreshold=j.getFloat("gyroThreshold");accelThreshold=j.getFloat("accelThreshold");
      gyroSign=j.getFloat("gyroSign");
      imuReady=true;previousImuMs=-1;
    }
    notice="Saved calibrations loaded. Recalibrate if the sensors were repositioned.";
  } catch(Exception e) {notice="Stored calibration unreadable; recalibrate sensors.";}
}

// ==========================================================================
// SENSOR FUSION + MOTION (actual measurements, never visual interpolation)
// ==========================================================================
// ---------------------------------------------------------------------------
// FILTRO COMPLEMENTARE ADATTATIVO.
// Integra il gyro nel tempo e usa l’angolo da gravita per correggerne lentamente la deriva;
// a riposo corregge piu rapidamente. A riposo prolungato aggiorna anche il bias gyro.
void updateOrientation(long t) {
  float accelAbsolute=degrees(atan2(ax,-ay));
  thetaAccel=wrap(accelAbsolute-accelZeroDeg); // zero anatomico sottratto al valore ACC
  float norm=sqrt(ax*ax+ay*ay+az*az);
  accelDev=abs(norm-gravityRef);
  float wx=gx-biasX,wy=gy-biasY,wz=gz-biasZ;
  omegaMag=sqrt(wx*wx+wy*wy+wz*wz);
  boolean quiet=omegaMag<gyroThreshold && accelDev<accelThreshold; // &&: entrambe le condizioni
  if(previousImuMs<0) {
    if(!imuResyncPending || quiet || Float.isNaN(thetaFused)) {
      thetaFused=thetaAccel;thetaGyro=thetaAccel;
      imuResyncPending=false;
    }
  } else if(imuResyncPending) {
    if(quiet) {
      thetaFused=thetaAccel;thetaGyro=thetaAccel;
      imuResyncPending=false;
      notice="MPU orientation re-synced; calibration retained.";
    }
  } else {
    // dt ricavato dai timestamp veri, non da un intervallo fisso di 40 ms.
    float dt=(t-previousImuMs)/1000.0;
    if(dt>0 && dt<=MAX_GYRO_DT_S) {
      float delta=degrees(gyroSign*wz*dt);  // variazione angolare = velocita * tempo
      thetaGyro=wrap(thetaGyro+delta);
      float predicted=wrap(thetaFused+delta);
      float tau=quiet?FUSION_TAU_STILL_S:FUSION_TAU_MOVING_S;
      float alpha=exp(-dt/max(0.01,tau)); // filtro indipendente dal sampling: exp(-dt/tau)
      thetaFused=wrap(predicted+(1-alpha)*wrap(thetaAccel-predicted)); // correzione verso gravita
    } else if(quiet) {
      thetaFused=thetaAccel;thetaGyro=thetaAccel;
    }
  }
  long previous=previousImuMs;
  previousImuMs=t;

  // Offset adaptation after 2 s of steady IMU angle, low rate and normal gravity.
  // Offset is NOT the anatomical zero (accelZeroDeg never updated here).
  // AUTO BIAS: prima 2 s di quiete; poi media esponenziale lentissima del gyro RAW.
  // Non modifica accelZeroDeg (origine anatomica).
  if(AUTO_GYRO_BIAS && !imuResyncPending) {
    boolean stable=omegaMag<BIAS_GYRO_LIMIT && accelDev<BIAS_ACCEL_LIMIT;
    if(!stable)biasStillFrom=-1;
    else if(biasStillFrom<0) {biasStillFrom=t;biasAngleStart=thetaAccel;}
    else if(abs(wrap(thetaAccel-biasAngleStart))>BIAS_ACCEL_ANGLE_DRIFT_LIMIT_DEG)
      {biasStillFrom=t;biasAngleStart=thetaAccel;}
    else if(t-biasStillFrom>=BIAS_STILL_MS && previous>=0) {
      float dt=(t-previous)/1000.0;
      if(dt>0 && dt<MAX_GYRO_DT_S) {
        float beta=1-exp(-dt/max(1,AUTO_GYRO_BIAS_TAU_S)); // passo MOLTO piccolo dell'offset
        biasX+=beta*(gx-biasX);
        biasY+=beta*(gy-biasY);
        biasZ+=beta*(gz-biasZ);
      }
    }
  }
}
// ---------------------------------------------------------------------------
// Azzera i candidati di inizio/fine movimento e i contatori di una nuova sessione.
void resetMotion() {
  inMotion=false;onsetCandidate=-1;offCandidate=-1;motionStart=-1;
  stillStart=sensorMs;lastMotionMs=-1;lastStillMs=-1;motionCount=0;
  movementStartedEvent=false;movementEndedEvent=false;
  motionWindowN=0;motionWindowI=0;
}
// ---------------------------------------------------------------------------
// DETECTOR: movimento se (gyro > soglia) OR (deviazione ACC > soglia).
// L’onset richiede ON_CONFIRM_MS; la fine richiede OFF_CONFIRM_MS.
// Il timestamp dell’evento e quello del PRIMO campione della condizione valida.
void updateMotion(long t) {
  gyroWindow[motionWindowI]=omegaMag;
  accelWindow[motionWindowI]=accelDev;
  motionWindowI=(motionWindowI+1)%gyroWindow.length;
  motionWindowN=Math.min(gyroWindow.length,motionWindowN+1);
  float om=0,ac=0;
  for(int i=0;i<motionWindowN;i++){om+=gyroWindow[i];ac+=accelWindow[i];}
  om/=motionWindowN;ac/=motionWindowN;
  boolean active=om>gyroThreshold || ac>accelThreshold; // ||: basta che UNO dei due segnali superi soglia
  movementStartedEvent=false;movementEndedEvent=false;
  if(imuResyncPending)return;
  // MACCHINA A STATI: conferma onset o offset prima di dichiarare l’evento.
  if(!inMotion) {
    offCandidate=-1;
    if(active) {
      if(onsetCandidate<0)onsetCandidate=t;
      if(t-onsetCandidate>=ON_CONFIRM_MS) {
        inMotion=true;motionStart=onsetCandidate;
        eventOnset=motionStart;movementStartedEvent=true;
        if(stillStart>=0)lastStillMs=motionStart-stillStart;
        onsetCandidate=-1;
      }
    } else onsetCandidate=-1;
  } else {
    onsetCandidate=-1;
    if(!active) {
      if(offCandidate<0)offCandidate=t;
      if(t-offCandidate>=OFF_CONFIRM_MS) {
        inMotion=false;eventOffset=offCandidate;
        lastMotionMs=Math.max(0L,eventOffset-motionStart);
        motionCount++;stillStart=eventOffset;
        movementEndedEvent=true;offCandidate=-1;
      }
    } else offCandidate=-1;
  }
}



// ==========================================================================
// TAB: Modes.pde
// ==========================================================================
// ==========================================================================
// ASSESSMENT + TRAINING: identical detection, different scoring
// ==========================================================================
// ---------------------------------------------------------------------------
// Apre Assessment/Training e resetta le misure della nuova sessione.
// Training eredita la durata GO -> fine reaching dell’ultimo Assessment salvato.
void openMode(int newPage) {
  boolean wantPreview=FORCE_UI_PREVIEW || !readySensors();
  if(wantPreview && !ALLOW_UI_PREVIEW) {
    notice="Both sensor calibrations and a live MPU stream are required.";
    return;
  }
  if(wantPreview)enterUiPreview(); // Fallback grafico senza calibrazione.
  page=newPage;
  resetMotion();
  trialPhase=READY;
  trialFeedback="";
  if(newPage==ASSESS)assessment.clear();
  if(newPage==TRAIN) {
    training.clear();
    // Training timer runs from GO, so assessment reference includes reaction + motion.
    float base=completedAssessment.size()==ASSESSMENT_TRIALS?
      averageTrial(completedAssessment,0)+averageTrial(completedAssessment,3):Float.NaN;
    trainTargetS=Float.isNaN(base)?TRAIN_MANUAL_TARGET_S:
      constrain(base*TRAIN_INITIAL_MARGIN,TRAIN_MIN_TARGET_S,TRAIN_MAX_TARGET_S);
  }
}
// ---------------------------------------------------------------------------
// Prepara un trial e avvia il conto alla rovescia senza creare altre schermate.
void beginCountdown() {
  if(!canRunActivity()) {notice="Sensor stream/calibration unavailable.";return;}
  trialPhase=COUNTDOWN;
  countdownStarted=millis();
  trialFeedback="";
  contactCandidate=-1;
  graspStarted=-1;
  reachStart=-1;reachEnd=-1;
  resetMotion();
  previewOnsetSent=false;previewEndSent=false;
}
// ---------------------------------------------------------------------------
// Gestisce countdown, avvio GO e timeout tramite millis() senza delay().
void tickTrial() {
  if(trialPhase==COUNTDOWN && millis()-countdownStarted>=COUNTDOWN_MS) {
    trialPhase=WAIT_START;
    trialGoSensor=sensorMs;trialGoHost=millis();
    baselineShoulder=thetaFused;baselineElbow=elbowDeg;
    minElbow=elbowDeg;
    maxShoulder=thetaFused;
    resetMotion();
  }
  if((trialPhase==WAIT_START || trialPhase==REACH || trialPhase==GRASP)
       && millis()-trialGoHost>MAX_TRIAL_MS+(trialPhase==GRASP?GRASP_TIMEOUT_MS:0)) {
    trialPhase=FAILED;
    trialFeedback="TIMEOUT - RETRY";
  }
  if(trialPhase==GRASP && millis()-trialEndHost>GRASP_TIMEOUT_MS) {
    trialPhase=FAILED;trialFeedback="GRASP NOT STABLE - RETRY";
  }
}
// ---------------------------------------------------------------------------
// LOGICA UNICA PER ASSESSMENT E TRAINING: calcola ROM e segue gli eventi.
// REACH finisce per STILLNESS oppure FSR CONTACT (OR); con FSR attivi segue GRASP.
void onTrialSample(long t) {
  if(trialPhase!=WAIT_START && trialPhase!=REACH && trialPhase!=GRASP)return;
  if(!canRunActivity())return;
  if(!Float.isNaN(elbowDeg)) {
    minElbow=min(minElbow,elbowDeg);
  }
  if(!Float.isNaN(thetaFused)) {
    maxShoulder=max(maxShoulder,thetaFused);
  }
  if(trialPhase==WAIT_START && movementStartedEvent && eventOnset>=trialGoSensor) {
    reachStart=eventOnset;
    trialPhase=REACH;
  }
  if(trialPhase!=REACH && trialPhase!=GRASP)return;
  // EVENTO FINE: contatto confermato OR fine del movimento rilevata da MPU.
  if(trialPhase==REACH) {
    boolean contacted=false;
    if(FSR_ENABLED && (thumbADC>=FSR_CONTACT_ADC || indexADC>=FSR_CONTACT_ADC)) {
      if(contactCandidate<0)contactCandidate=t;
      if(t-contactCandidate>=FSR_CONTACT_CONFIRM_MS)contacted=true;
    } else contactCandidate=-1;

    // The OR selects the first confirmed event, not two mandatory conditions.
    if(contacted)endReaching(contactCandidate);
    else if(movementEndedEvent)endReaching(eventOffset);
  } else if(trialPhase==GRASP) {
    // GRASP: entrambe le dita devono restare nella fascia di forza contemporaneamente.
    boolean thumbOK=thumbADC>=FSR_TARGET_MIN_ADC && thumbADC<=FSR_TARGET_MAX_ADC;
    boolean indexOK=indexADC>=FSR_TARGET_MIN_ADC && indexADC<=FSR_TARGET_MAX_ADC;
    if(thumbOK && indexOK) {
      if(graspStarted<0)graspStarted=t;
      if(t-graspStarted>=GRASP_HOLD_MS)finishTrial(true);
    } else graspStarted=-1;   // uninterrupted 3s, both FSRs in band
  }
}
// ---------------------------------------------------------------------------
// Convalida la fine del reaching: durata e ROM minimi eliminano falsi positivi.
// Con FSR attivi passa a GRASP; altrimenti conclude subito il trial.
void endReaching(long tEnd) {
  if(reachStart<0 || tEnd<reachStart)return;
  float sROM=max(0,maxShoulder-baselineShoulder);
  float eROM=max(0,baselineElbow-minElbow);
  // Reject sensor spikes / tiny motions and allow another reach in the same trial.
  // Non confondere un piccolo movimento casuale con un raggiungimento valido.
  if(tEnd-reachStart<MIN_REACH_MS || max(sROM,eROM)<MIN_REACH_ROM_DEG) {
    trialPhase=WAIT_START;reachStart=-1;resetMotion();
    return;
  }
  reachEnd=tEnd;trialEndHost=millis();
  // Sensori di forza opzionali: se OFF, Assessment e Training restano indipendenti.
  if(FSR_ENABLED) {trialPhase=GRASP;graspStarted=-1;}
  else finishTrial(false);
}
// ---------------------------------------------------------------------------
// Congela le metriche del trial e calcola il feedback temporale nel Training.
void finishTrial(boolean graspOK) {
  float reaction=max(0,reachStart-trialGoSensor)/1000.0;
  float duration=max(0,reachEnd-reachStart)/1000.0;
  float shROM=max(0,maxShoulder-baselineShoulder);
  float elROM=max(0,baselineElbow-minElbow);
  String fb="COMPLETED";
  float target=Float.NaN;
  // TRAINING: il target temporale parte da GO, include il tempo di reazione.
  // La qualita del gesto e verificata separatamente dal tempo.
  if(page==TRAIN) {
    target=trainTargetS;
    float goToEnd=max(0,reachEnd-trialGoSensor)/1000.0; // reaction + movement, dal GO
    if(goToEnd<target*(1-TRAIN_ON_TIME_TOLERANCE))fb="TOO EARLY";
    else if(goToEnd>target*(1+TRAIN_ON_TIME_TOLERANCE))fb="TOO SLOW";
    else fb="ON TIME";
    if(!qualityROM(shROM,elROM))fb+=" / LOW ROM";
  }
  Trial result=new Trial(reaction,duration,baselineShoulder,baselineElbow,
                         maxShoulder,shROM,minElbow,elROM,
                         FSR_ENABLED?(millis()-trialEndHost)/1000.0:Float.NaN,
                         graspOK,target,fb);
  if(page==ASSESS)assessment.add(result);
  if(page==TRAIN)training.add(result);
  trialFeedback=fb;
  trialPhase=COMPLETE;
  if(page==TRAIN && training.size()%TRAIN_ADAPT_EVERY==0)adaptTraining();
}
// ---------------------------------------------------------------------------
// Verifica che il ROM del Training non sia troppo piccolo rispetto all’Assessment.
boolean qualityROM(float sROM,float eROM) {
  if(completedAssessment.size()!=ASSESSMENT_TRIALS)return true; // manual training
  float minS=averageTrial(completedAssessment,1)*TRAIN_MIN_ROM_FRACTION;
  float minE=averageTrial(completedAssessment,2)*TRAIN_MIN_ROM_FRACTION;
  return sROM>=minS && eROM>=minE;
}
// ---------------------------------------------------------------------------
// Adattamento semplice: ogni due trial validi aggiorna il target del 5%.
void adaptTraining() {
  int n=training.size();
  if(n<TRAIN_ADAPT_EVERY)return;
  boolean bothGood=true, bothSlow=true;
  // Guarda soltanto le ultime TRAIN_ADAPT_EVERY ripetizioni completate.
  for(int i=n-TRAIN_ADAPT_EVERY;i<n;i++) {
    Trial t=training.get(i);
    boolean good=abs(t.reactionS+t.movementS-t.targetS)<=t.targetS*TRAIN_ON_TIME_TOLERANCE
       && qualityROM(t.shoulderExcursion,t.elbowExtension);
    boolean slow=t.reactionS+t.movementS>t.targetS*(1+TRAIN_ON_TIME_TOLERANCE)
       || !qualityROM(t.shoulderExcursion,t.elbowExtension);
    bothGood &=good;
    bothSlow &=slow;
  }
  if(bothGood)trainTargetS*=1-TRAIN_ADAPT_FRACTION;
  else if(bothSlow)trainTargetS*=1+TRAIN_ADAPT_FRACTION;
  trainTargetS=constrain(trainTargetS,TRAIN_MIN_TARGET_S,TRAIN_MAX_TARGET_S);
}
// Le metriche si estraggono sempre nello stesso modo: niente duplicazione tra media e SD.
// 0=durata, 1=ROM spalla, 2=estensione gomito, 3=reazione, 4=max spalla, 5=min gomito.
// ---------------------------------------------------------------------------
// Seleziona UNA variabile del trial, riutilizzata da media e deviazione standard.
float trialMetric(Trial t,int metric) {
  if(metric==0)return t.movementS;
  if(metric==1)return t.shoulderExcursion;
  if(metric==2)return t.elbowExtension;
  if(metric==3)return t.reactionS;
  if(metric==4)return t.shoulderMaximum;
  return t.elbowMinimum;
}
// ---------------------------------------------------------------------------
// Media aritmetica della metrica richiesta sulle prove completate.
float averageTrial(ArrayList<Trial> trials,int metric) {
  if(trials.isEmpty())return Float.NaN;
  float total=0;
  for(Trial t:trials)total+=trialMetric(t,metric);
  return total/trials.size();
}
// ---------------------------------------------------------------------------
// Deviazione standard campionaria: misura la variabilita delle ripetizioni.
float sdTrial(ArrayList<Trial> trials,int metric) {
  if(trials.size()<2)return Float.NaN;
  float mean=averageTrial(trials,metric),sumSq=0;
  for(Trial t:trials) {
    float error=trialMetric(t,metric)-mean;
    sumSq+=error*error;
  }
  return sqrt(sumSq/(trials.size()-1)); // sqrt = radice; N-1 per SD campionaria
}

// ==========================================================================
// GAME: FK from two measured joint angles and reachable target generation
// ==========================================================================
// ---------------------------------------------------------------------------
// CINEMATICA DIRETTA: X del polso da elevazione spalla e angolo gomito [m].
float wristX(float sh,float el) {
  return UPPER_ARM_M*sin(radians(sh))+FOREARM_M*sin(radians(sh+el));
}
// ---------------------------------------------------------------------------
// CINEMATICA DIRETTA: Y positiva VERSO IL BASSO nello schermo [m].
float wristY(float sh,float el) {
  return UPPER_ARM_M*cos(radians(sh))+FOREARM_M*cos(radians(sh+el));
}
// ---------------------------------------------------------------------------
// CINEMATICA INVERSA: verifica che una coordinata X,Y ammetta angoli nei ROM.
// Usa il coseno dell’angolo al gomito e atan2 per ricavare l’angolo di spalla.
boolean reachable(float x,float y) {
  float r2=x*x+y*y;
// Legge del coseno (IK): lunghezze note + distanza del target -> angolo al gomito.
  float cosEl=(r2-UPPER_ARM_M*UPPER_ARM_M-FOREARM_M*FOREARM_M)/
              (2*UPPER_ARM_M*FOREARM_M);
  // cosEl fisicamente possibile solo nell’intervallo [-1,1].
  if(cosEl< -1 || cosEl>1)return false;
  float elbow=degrees(acos(constrain(cosEl,-1,1)));
  float shoulder=degrees(atan2(x,y)-atan2(FOREARM_M*sin(radians(elbow)),
                                              UPPER_ARM_M+FOREARM_M*cos(radians(elbow))));
  return shoulder>=gameShMin-0.01 && shoulder<=gameShMax+0.01 &&
         elbow>=gameElMin-0.01 && elbow<=gameElMax+0.01;
}
// ---------------------------------------------------------------------------
// Controlla l’intero percorso con 36 punti, non soltanto gli estremi.
boolean pathReachable(float ax,float ay,float bx,float by) {
  for(int i=0;i<=35;i++) {
    float t=i/35.0;
    if(!reachable(lerp(ax,bx,t),lerp(ay,by,t)))return false;
  }
  return true;
}
// ---------------------------------------------------------------------------
// Genera sei target da pose articolari lecite e due segmenti raggiungibili.
// Se il ROM disponibile e limitato, accorcia progressivamente i segmenti.
void generateGameTargets() {
  for(int k=0;k<2;k++) {
    for(int j=0;j<2;j++) {trackStart[k][j]=0;trackEnd[k][j]=0;}
  }
  gameShMin=GAME_SHOULDER_MIN_DEG;gameShMax=GAME_SHOULDER_MAX_DEG;
  gameElMin=GAME_ELBOW_MIN_DEG;gameElMax=GAME_ELBOW_MAX_DEG;
  if(GAME_USE_ASSESSMENT_ROM && completedAssessment.size()==ASSESSMENT_TRIALS) {
    // Patient-specific measured range is safer than assuming 0-90° is available.
    float shStart=0,shMax=0,elStart=0,elMin=0;
    for(Trial t:completedAssessment){
      shStart+=t.initialShoulder;shMax+=t.shoulderMaximum;
      elStart+=t.initialElbow;elMin+=t.elbowMinimum;
    }
    int n=completedAssessment.size();
    gameShMin=max(gameShMin,shStart/n+2);
    gameShMax=min(gameShMax,shMax/n-2);
    gameElMin=max(gameElMin,elMin/n+2);
    gameElMax=min(gameElMax,elStart/n-2);
    // Avoid empty spans caused by noise. If ROM is tiny, targets remain close.
    if(gameShMax<=gameShMin)gameShMax=gameShMin+1;
    if(gameElMax<=gameElMin)gameElMax=gameElMin+1;
  }
  float[][] fractions={{0.23,0.74},{0.45,0.66},{0.70,0.40},
                       {0.78,0.73},{0.37,0.32},{0.58,0.52}};
  for(int i=0;i<GAME_STATIC_COUNT;i++) {
    float sh=lerp(gameShMin,gameShMax,fractions[i%6][0]); // pose in ROM, non punti casuali sullo schermo
    float el=lerp(gameElMin,gameElMax,fractions[i%6][1]);
    gameX[i]=wristX(sh,el);gameY[i]=wristY(sh,el);
  }
  // Horizontal and diagonal linear paths. Check ALL intermediate points with IK.
  for(int k=0;k<2;k++) {
    float sh=lerp(gameShMin,gameShMax,k==0?0.52:0.59);
    float el=lerp(gameElMin,gameElMax,k==0?0.54:0.48);
    float cx=wristX(sh,el),cy=wristY(sh,el);
    float len=GAME_TRACK_DISTANCE_M;
    for(int n=0;n<12;n++) {
      float dx=len*0.5,dy=k==0?0:len*0.33;
      float x1=cx-dx,y1=cy+dy,x2=cx+dx,y2=cy-dy;
      if(pathReachable(x1,y1,x2,y2)) {
        trackStart[k][0]=x1;trackStart[k][1]=y1;
        trackEnd[k][0]=x2;trackEnd[k][1]=y2;
        break;
      }
      len*=0.72;
    }
    // Nessuna traiettoria sicura? Rimane un punto fisso per non uscire dal workspace.
    if(trackStart[k][0]==0 && trackStart[k][1]==0) {
      // Always safe fallback: a stationary point (very restricted ROM).
      trackStart[k][0]=trackEnd[k][0]=cx;
      trackStart[k][1]=trackEnd[k][1]=cy;
    }
  }
}
// ---------------------------------------------------------------------------
// Apre il gioco soltanto se entrambe le stime angolari sono disponibili.
void openGame() {
  boolean wantPreview=FORCE_UI_PREVIEW || !readySensors();
  if(wantPreview && !ALLOW_UI_PREVIEW) {
    notice="Game requires both calibrated joint angles.";return;
  }
  if(wantPreview)enterUiPreview();
  page=GAME;gamePhase=GAME_READY;
  previewGameShoulder=35;previewGameElbow=70;
}
// ---------------------------------------------------------------------------
// Inizializza i risultati e presenta il primo target statico.
void startGame() {
  generateGameTargets();
  if(uiPreview) {
    previewGameShoulder=(gameShMin+gameShMax)/2;
    previewGameElbow=(gameElMin+gameElMax)/2;
  }
  gameHits=0;gameStaticIndex=0;gameTrackIndex=0;gameOverlapFrom=-1;
  for(int i=0;i<GAME_STATIC_COUNT;i++) {staticResponse[i]=Float.NaN;staticSucceeded[i]=0;}
  for(int i=0;i<2;i++) {trackMeanError[i]=Float.NaN;trackOnPercent[i]=0;}
  gamePhase=GAME_STATIC;gameTargetHost=millis();
}
float[] trackMeanError=new float[2];
float[] trackOnPercent=new float[2];
// ---------------------------------------------------------------------------
// Inizia il tracking orizzontale (0) oppure diagonale (1).
void startTrack(int k) {
  gamePhase=GAME_TRACK;gameTrackIndex=k;gamePhaseHost=millis();
  trackDistanceSum=0;trackOnTimeMs=0;trackTotalTimeMs=0;
  trackN=0;previousTrackSensor=-1;
}
// ---------------------------------------------------------------------------
// Calcola la coordinata corrente della pallina: fissa o interpolata lungo il percorso.
float[] currentGameTarget() {
  if(gamePhase==GAME_STATIC)return new float[]{gameX[gameStaticIndex],gameY[gameStaticIndex]};
  if(gamePhase==GAME_TRACK) {
    float f=constrain((millis()-gamePhaseHost)/(float)GAME_TRACK_MS,0,1);
    return new float[]{lerp(trackStart[gameTrackIndex][0],trackEnd[gameTrackIndex][0],f),
                       lerp(trackStart[gameTrackIndex][1],trackEnd[gameTrackIndex][1],f)};
  }
  return new float[]{0,0};
}
// ---------------------------------------------------------------------------
// Misura la distanza mano-target con le misure originali (NON il disegno smussato).
// Basta la sovrapposizione delle due aree circolari; i tempi vengono dai timestamp.
void onGameSample(long t) {
  if(!canRunActivity() || Float.isNaN(elbowDeg) || Float.isNaN(thetaFused))return;
  if(gamePhase!=GAME_STATIC && gamePhase!=GAME_TRACK)return;
  if(gamePhase==GAME_STATIC && millis()<gameTargetHost)return;
  float[] target=currentGameTarget(); // array di due elementi: target X e Y [metri]
  float dx=wristX(thetaFused,elbowDeg)-target[0];
  float dy=wristY(thetaFused,elbowDeg)-target[1];
  float d=sqrt(dx*dx+dy*dy);
  boolean overlap=d<=(GAME_TARGET_RADIUS_M+GAME_HAND_RADIUS_M);
  if(gamePhase==GAME_STATIC) {
    // TARGET STATICO: area della mano e della pallina possono sovrapporsi PARZIALMENTE.
    if(overlap) {
      if(gameOverlapFrom<0)gameOverlapFrom=millis();
      if(millis()-gameOverlapFrom>=GAME_STATIC_HOLD_MS)advanceStatic(true);
    } else gameOverlapFrom=-1;
  } else {
    trackDistanceSum+=d;trackN++;
    if(previousTrackSensor>=0) {
      long dt=t-previousTrackSensor;
      if(dt>0 && dt<220) {
        trackTotalTimeMs+=dt;
        if(overlap)trackOnTimeMs+=dt;
      }
    }
    previousTrackSensor=t;
  }
}
// ---------------------------------------------------------------------------
// Registra successo/timeout del target e passa al successivo.
void advanceStatic(boolean success) {
  if(success) {
    gameHits++;
    staticSucceeded[gameStaticIndex]=1;
    staticResponse[gameStaticIndex]=max(0,gameOverlapFrom-gameTargetHost)/1000.0;
  }
  gameStaticIndex++;
  gameOverlapFrom=-1;
  if(gameStaticIndex>=GAME_STATIC_COUNT)startTrack(0);
  else gameTargetHost=millis()+GAME_BETWEEN_TARGET_MS;
}
// ---------------------------------------------------------------------------
// Gestisce i timeout e il passaggio automatico ai due inseguimenti.
void tickGame() {
  if(gamePhase==GAME_STATIC && millis()>=gameTargetHost+
      GAME_STATIC_TIMEOUT_MS)advanceStatic(false);
  // Il tracking finisce per tempo, e restituisce errore medio + tempo dentro target.
  if(gamePhase==GAME_TRACK && millis()-gamePhaseHost>=GAME_TRACK_MS) {
    trackMeanError[gameTrackIndex]=trackN>0?trackDistanceSum/trackN:Float.NaN;
    trackOnPercent[gameTrackIndex]=trackTotalTimeMs>0?
        100*trackOnTimeMs/trackTotalTimeMs:0;
    if(gameTrackIndex==0)startTrack(1);
    else gamePhase=GAME_RESULTS;
  }
}
// ---------------------------------------------------------------------------
// Media dei tempi raggiungimento SOLO sui target statici validi.
float meanResponse() {
  float s=0;int n=0;
  for(int i=0;i<GAME_STATIC_COUNT;i++)if(staticSucceeded[i]==1){s+=staticResponse[i];n++;}
  return n>0?s/n:Float.NaN;
}



// ==========================================================================
// TAB: UI.pde
// ==========================================================================
// ==========================================================================
// DRAW — one operating screen per mode; results replace it at session end
// ==========================================================================
// ---------------------------------------------------------------------------
// RENDER LOOP — Processing richiama draw() a ogni frame (UI_FPS).
// Aggiorna i timer delle modalita e disegna SOLO la pagina scelta; niente delay().
void draw() {
  background(255);                        // riempie TUTTA la finestra di bianco ad ogni frame
  if(page==FLEX)tickFlex();
  if(page==IMU && imuPhase==1 && millis()-imuStarted>=IMU_CAL_MS)finishImu();
  if(page==ASSESS || page==TRAIN)tickTrial();
  if(uiPreview)tickUiPreview(); // Genera angoli e grafici fittizi solo in anteprima.
  if(page==GAME)tickGame();
  updateVisualAngles();
  if(page==HOME)drawHome();
  else if(page==FLEX)drawFlex();
  else if(page==IMU)drawImu();
  else if(page==LIVE)drawLive();
  else if(page==ASSESS || page==TRAIN)drawTrialPage();
  else if(page==GAME)drawGame();
  footer();
}
// ---------------------------------------------------------------------------
// FILTRO SOLO GRAFICO: il modello 2D rincorre l’ultimo angolo misurato.
// A differenza di elbowDeg/thetaFused, non viene mai usato per misure o risultati.
void updateVisualAngles() {
  int now=millis();
  float dt=lastDisplayMs<=0?1:(now-lastDisplayMs);
  lastDisplayMs=now;
  float k=USE_VISUAL_SMOOTHING?1-exp(-dt/max(1,VISUAL_TAU_MS)):1; // 1 = nessuno smoothing
  if((imuReady || uiPreview) && !Float.isNaN(thetaFused)) {
    if(Float.isNaN(displayShoulder))displayShoulder=thetaFused;
    else displayShoulder+=k*wrap(thetaFused-displayShoulder);
  } else displayShoulder=Float.NaN;
  if((flexReady || uiPreview) && !Float.isNaN(elbowDeg)) {
    if(Float.isNaN(displayElbow))displayElbow=elbowDeg;
    else displayElbow+=k*(elbowDeg-displayElbow);
  } else displayElbow=Float.NaN;
}
// ---------------------------------------------------------------------------
// UI: titolo, sottotitolo e linea orizzontale uguali in tutte le pagine.
void heading(String title,String subtitle) {
  fill(0);textAlign(LEFT,BASELINE);textSize(30);text(title,42,56); // fill colore testo; textSize px
  fill(85);textSize(14);text(subtitle,43,84);
  stroke(0);strokeWeight(1);line(42,102,1258,102); // stroke colore contorno, strokeWeight spessore
  if(uiPreview) { // Avviso in ogni modalita: misure e risultati NON sono reali.
    fill(180,70,32);textAlign(RIGHT,BASELINE);textSize(14);
    text("UI PREVIEW  |  SIMULATED DATA",1250,78);
    textAlign(LEFT,BASELINE);
  }
}
// ---------------------------------------------------------------------------
// UI: disegna un rettangolo bianco contornato con angoli arrotondati.
void panel(float x,float y,float w,float h) {
  stroke(0);strokeWeight(1);fill(255);rect(x,y,w,h,8); // rect: x,y,w,h,raggio angoli
}
// ---------------------------------------------------------------------------
// UI: disegna un bottone scuro o chiaro; il click e gestito in mousePressed().
void button(String label,float x,float y,float w,float h,boolean dark) {
  stroke(0);strokeWeight(1);fill(dark?0:255);rect(x,y,w,h,7); // ?: operatore condizionale breve
  fill(dark?255:0);textAlign(CENTER,CENTER);textSize(15);
  text(label,x+w/2,y+h/2-1);
  textAlign(LEFT,BASELINE);
}
// ---------------------------------------------------------------------------
// UI: testo piccolo grigio per descrivere una misura.
void label(String s,float x,float y) {fill(100);textSize(13);text(s,x,y);}
// ---------------------------------------------------------------------------
// UI: numero grande per mettere in evidenza la misura.
void number(String s,float x,float y) {fill(0);textSize(24);text(s,x,y);}
// ---------------------------------------------------------------------------
// UI: barra inferiore con stato seriale, frequenza dati, backlog e reset.
void footer() {
  if(uiPreview) {
    fill(150,65,31);textSize(12);textAlign(RIGHT,BASELINE);
    text("UI PREVIEW — NO SENSOR CALIBRATION REQUIRED · NO DATA SAVED",1257,804);
    textAlign(LEFT,BASELINE);
    return;
  }
  fill(95);textSize(12);textAlign(RIGHT,BASELINE);
  text("COM "+PORT+"  |  "+(fresh()?"STREAM OK":"STREAM LOST")+
       "  |  RX "+v(rxHz,1)+" Hz  |  BACKLOG +"+backlogMs+" ms"+
       "  |  "+(mpuValid?"MPU OK":"MPU INVALID")+
       "  |  RESTARTS "+arduinoRestarts+"  |  BAD TS "+badTimestamps,
       1257,804);
  textAlign(LEFT,BASELINE);
}
// ---------------------------------------------------------------------------
// UI: pannello cliccabile HOME, con titolo, descrizione e stato.
void homeCard(float x,float y,float w,float h,String title,String subtitle,String stat) {
  panel(x,y,w,h);
  fill(0);textSize(20);text(title,x+17,y+36);
  fill(85);textSize(14);text(subtitle,x+17,y+66);
  fill(50);textSize(14);text(stat,x+17,y+h-29);
  fill(0);textAlign(RIGHT,BASELINE);textSize(15);text("OPEN",x+w-17,y+h-29);
  textAlign(LEFT,BASELINE);
}
// ---------------------------------------------------------------------------
// SCHERMATA HOME: selettore per calibrazioni, live, assessment, training e gioco.
void drawHome() {
  heading("REACH-TO-GRASP", "Calibrate once, then select an activity. Each module uses the same measured joint angles.");
  panel(42,139,386,220);
  fill(0);textSize(20);text("01  CALIBRATION",59,175);
  label("Saved sensors: "+(flexReady?"FLEX OK":"FLEX NOT READY")+
        "   |   "+(imuReady?"MPU OK":"MPU NOT READY"),59,213);
  label("Choose which calibration to repeat:",59,265);
  button("FLEX",59,292,164,47,true);
  button("MPU-6050",242,292,168,47,true);
  homeCard(457,139,386,220,"02  LIVE MONITOR",
           "Arm model, angles, signal checks",fresh()?"SENSOR LIVE":"NO SENSOR DATA");
  homeCard(872,139,386,220,"03  ASSESSMENT",
           ASSESSMENT_TRIALS+" guided reach-to-grasp trials",
           completedAssessment.size()==ASSESSMENT_TRIALS?"REFERENCE SESSION SAVED":"NO FINISHED SESSION");
  homeCard(42,385,593,220,"04  TRAINING",
           "GO timer, visual feedback and adaptation every "+TRAIN_ADAPT_EVERY+" trials",
           completedAssessment.size()==ASSESSMENT_TRIALS?"USES SAVED ASSESSMENT":"USES MANUAL STARTING TARGET");
  homeCard(663,385,595,220,"05  TARGET TRACKING GAME",
           "6 static targets + 2 moving paths in the reachable workspace","2D WRIST MODEL");
  panel(42,631,1216,108);
  fill(0);textSize(15);text("STATUS",60,659);
  fill(82);textSize(14);
  text(notice,60,686,1170,46);
  fill(105);textSize(12);
  text("Saved calibrations remain valid only while the sensor mounting stays unchanged.",60,730);
  // Se le calibrazioni non sono disponibili, l'accesso apre una preview simulata.
  if(ALLOW_UI_PREVIEW && !readySensors()) {
    fill(94);textSize(12);
    text("Assessment / Training / Game can be opened without sensors (UI preview).",666,729);
  }
}
// ---------------------------------------------------------------------------
// SCHERMATA CALIBRAZIONE FLEX: posa richiesta, conto alla rovescia e ADC.
void drawFlex() {
  heading("FLEX CALIBRATION","0° → 45° → 90° → 120° → 90° → 45° → 0°. Repeat cycles or stop after all four holds.");
  panel(42,132,765,581);panel(825,132,433,581);
  if(flexPhase==0) {
    fill(0);textSize(29);text("READY",73,193);
    fill(75);textSize(18);
    text("Place the flex on the posterior elbow.",73,247);
    text("Follow each angle using a goniometer.",73,284);
    text("Move for 1 s, then hold for 5 s.",73,321);
    text("Only COMPLETED holds are averaged.",73,358);
  } else {
    int elapsed=millis()-flexPhaseStarted;
    int duration=flexPhase==1?FLEX_MOVE_MS:FLEX_HOLD_MS;
    label(flexPhase==1?"MOVE TO":"HOLD STILL AT",72,192);
    fill(0);textSize(95);text(FLEX_STEPS[flexStep]+"°",70,309);
    number(v(max(0,duration-elapsed)/1000.0,1)+" s remaining",73,371);
    label("STEP "+(flexStep+1)+" / 7   |   FULL CYCLES "+fullFlexCycles,73,424);
    stroke(0);noFill();rect(74,465,660,16);
    noStroke();fill(0);rect(74,465,660*constrain(elapsed/(float)duration,0,1),16);
  }
  label("RAW FLEX",850,183);number(flexADC+" ADC",850,221);
  label("ESTIMATED ELBOW",850,288);number(flexReady?v(elbowDeg,1)+"°":"--",850,326);
  label("COMPLETED HOLD AVERAGES (ADC)",850,400);
  for(int i=0;i<4;i++) {
    String m=flexPhase!=0 && flexPoseHolds[i]>0?
             v(flexPoseSum[i]/flexPoseHolds[i],1):
             flexPhase==0 && flexReady?v(flexAnchors[i],1):"--";
    fill(20);textSize(16);text(FLEX_ANGLES[i]+"°   "+m+"   ("+flexPoseHolds[i]+" holds)",850,439+i*39);
  }
  if(flexPhase==0)button("START",42,730,180,48,true);
  else button("STOP + SAVE",42,730,200,48,true);
  button("HOME",266,730,170,48,false);
}
// ---------------------------------------------------------------------------
// SCHERMATA CALIBRAZIONE MPU: statistiche, soglie e motivo di eventuale errore.
void drawImu() {
  heading("MPU-6050 CALIBRATION","Hold the upper arm along the trunk, stationary. Minor case tilt is included in the zero reference.");
  panel(42,132,780,581);panel(839,132,419,581);
  fill(0);textSize(26);
  text(imuPhase==0?"READY":imuPhase==1?"CALIBRATING":
       imuCalSuccess?"CALIBRATION SUCCESSFUL":"CALIBRATION FAILED",70,184);
  label("+Y roughly towards elbow; +X towards anterior; +Z sagittal gyro axis.",70,225);
  if(imuPhase==1) {
    number(v(max(0,IMU_CAL_MS-(millis()-imuStarted))/1000.0,1)+" s",70,291);
    label(imuN+" valid sensor samples",70,325);
  } else if(imuPhase==2) {
    fill(0);textSize(16);text(imuFailure.equals("None")?"All checks passed.":imuFailure,
                               70,262,720,80);
  }
  label("ACTUAL BASELINE STATISTICS  /  ACCEPTED RANGE",70,363);
  drawCheck("VALID SAMPLES",imuSamplesLast+"",">= "+IMU_MIN_SAMPLES,imuSamplesLast>=IMU_MIN_SAMPLES,70,395);
  drawCheck("ACC MAGNITUDE",v(imuLastNorm,2)+" m/s²",
            v(IMU_NORM_MIN,1)+"–"+v(IMU_NORM_MAX,1),
            imuLastNorm>=IMU_NORM_MIN && imuLastNorm<=IMU_NORM_MAX,70,439);
  drawCheck("ACC XY PROJECTION",v(imuLastXY,2)+" m/s²",">= "+v(IMU_MIN_XY,1),
            imuLastXY>=IMU_MIN_XY,70,483);
  drawCheck("GYRO SD",v(imuLastGyroSD,3)+" rad/s","<= "+v(IMU_GYRO_SD_MAX,2),
            imuLastGyroSD<=IMU_GYRO_SD_MAX,70,527);
  drawCheck("ACC NORM SD",v(imuLastAccelSD,3)+" m/s²","<= "+v(IMU_ACCEL_SD_MAX,2),
            imuLastAccelSD<=IMU_ACCEL_SD_MAX,70,571);
  label("A failed attempt never deletes the previous valid calibration.",70,669);
  label("RAW ACC X",863,180);number(v(ax,2)+" m/s²",863,216);
  label("RAW ACC Y",863,282);number(v(ay,2)+" m/s²",863,318);
  label("RAW ACC Z",863,384);number(v(az,2)+" m/s²",863,420);
  label("SENSOR",863,486);number(mpuValid?"MPU OK":"UNAVAILABLE",863,523);
  label("CALIBRATION STORED",863,586);
  number(imuReady?"YES":"NO",863,623);
  if(imuPhase!=1)button("START / REPEAT",42,730,200,48,true);
  else button("CALIBRATING",42,730,200,48,false);
  button("HOME",266,730,170,48,false);
}
// ---------------------------------------------------------------------------
// UI: mostra misura, intervallo accettabile e PASS/FAIL.
void drawCheck(String name,String measured,String limit,boolean passed,float x,float y) {
  fill(20);textSize(14);text(name,x,y);
  fill(70);text(measured,x+237,y);
  text(limit,x+456,y);
  if(imuPhase==2){fill(passed?color(28,141,68):color(197,47,47));}
  else fill(150);
  textSize(13);text(imuPhase==2?(passed?"PASS":"FAIL"):"--",x+642,y);
}

// Fixed-axis and fixed 5-second history, measured joint angles (not raw ADC).
// ---------------------------------------------------------------------------
// GRAFICO ULTIMI 5 s: ascissa temporale mobile, ordinata a scala fissa.
// Disegna la linea verde del target e unisce solo campioni con timestamp vicini.
void anglePlot(float x,float y,float w,float h,boolean shoulder) {
  float minimum=shoulder?SHOULDER_GRAPH_MIN:ELBOW_GRAPH_MIN;
  float maximum=shoulder?SHOULDER_GRAPH_MAX:ELBOW_GRAPH_MAX;
  float target=shoulder?SHOULDER_TARGET_DEG:ELBOW_TARGET_DEG;
  String name=shoulder?"SHOULDER ELEVATION (MPU)":"ELBOW FLEXION";
  panel(x,y,w,h);
  fill(0);textSize(17);text(name,x+18,y+29);
  String current=shoulder?v(thetaFused,1):v(elbowDeg,1);
  fill(0);textAlign(RIGHT,BASELINE);textSize(20);text(current+"°",x+w-18,y+29);
  textAlign(LEFT,BASELINE);
  float gx=x+65,gy=y+51,gw=w-86,gh=h-94;
  // Griglia orizzontale e numeri: asse verticale a scala FISSA (non autoscale).
  for(int i=0;i<=4;i++) {
    float val=lerp(minimum,maximum,i/4.0);
    float yy=gy+gh-i*gh/4;
    stroke(225);strokeWeight(1);line(gx,yy,gx+gw,yy);
    fill(95);textSize(12);text(v(val,0)+"°",x+10,yy+4);
  }
  stroke(110);strokeWeight(1);line(gx,gy,gx,gy+gh); // stroke: colore delle linee
  float tY=gy+gh-(target-minimum)/(maximum-minimum)*gh;
  stroke(37,170,75);strokeWeight(2.5);line(gx,tY,gx+gw,tY); // linea verde target
  fill(33,134,58);textSize(12);text("TARGET "+v(target,0)+"°",gx+7,max(gy+13,tY-7));
  // La finestra scorre sui 5 s precedenti al timestamp Arduino piu recente.
  long left=sensorMs-GRAPH_WINDOW_MS;
  boolean prior=false;float priorX=0,priorY=0;long priorT=0;
  stroke(12);strokeWeight(2);noFill();
  // Each point uses the true sensor timestamp; a gap breaks the polyline.
  // Disegna la storia cronologica nel buffer circolare, senza spezzarla ai bordi.
  for(int i=0;i<plotN;i++) {
    int k=(plotHead-plotN+i+HISTORY)%HISTORY;
    if(plotT[k]<left){prior=false;continue;}
    float z=shoulder?plotShoulder[k]:plotElbow[k];
    if(Float.isNaN(z)) {prior=false;continue;}
    float xx=gx+constrain((plotT[k]-left)/(float)GRAPH_WINDOW_MS,0,1)*gw; // clamp 0..1 nel grafico
    float yy=gy+gh-(z-minimum)/(maximum-minimum)*gh;
    yy=constrain(yy,gy,gy+gh);
    if(prior && plotT[k]-priorT<GRAPH_BREAK_MS)line(priorX,priorY,xx,yy); // disegna un segmento
    prior=true;priorX=xx;priorY=yy;priorT=plotT[k];
  }
  fill(100);textSize(12);text("-5 s",gx,gy+gh+24); // etichetta del bordo sinistro
  textAlign(RIGHT,BASELINE);text("NOW",gx+gw,gy+gh+24);
  textAlign(LEFT,BASELINE);
}
// ---------------------------------------------------------------------------
// MODELLO 2D: usa le lunghezze del braccio per disegnare due segmenti.
// È solo in Live Monitor e Game: Assessment/Training usano i grafici angolari.
void drawArm(float x0,float y0,float lengthScale) {
  float sh=Float.isNaN(displayShoulder)?0:displayShoulder;
  float el=Float.isNaN(displayElbow)?90:displayElbow;
  float ex=x0+UPPER_ARM_M*lengthScale*sin(radians(sh));
  float ey=y0+UPPER_ARM_M*lengthScale*cos(radians(sh));
  float wx=ex+FOREARM_M*lengthScale*sin(radians(sh+el));
  float wy=ey+FOREARM_M*lengthScale*cos(radians(sh+el));
  stroke(200);strokeWeight(1);line(x0,y0-25,x0,y0+300);
  stroke(0);strokeWeight(12);line(x0,y0,ex,ey);
  stroke(80);strokeWeight(9);line(ex,ey,wx,wy);
  noStroke();fill(0);ellipse(x0,y0,14,14);
  fill(110);ellipse(ex,ey,14,14);
  fill(20);ellipse(wx,wy,17,17);
}
// ---------------------------------------------------------------------------
// LIVE MONITOR: visualizza il modello 2D e i dati di diagnostica.
void drawLive() {
  heading("LIVE MONITOR","Live arm visualization and sensor diagnostics. Movement is detected from MPU; angle data remain unaltered.");
  panel(42,128,598,588);panel(658,128,600,588);
  fill(0);textSize(19);text("PLANAR ARM (VISUAL ONLY)",62,163);
  drawArm(177,224,410);
  label("SHOULDER (FUSED)",65,540);number(imuReady?v(thetaFused,1)+"°":"--",65,577);
  label("ELBOW (FLEX)",350,540);number(flexReady?v(elbowDeg,1)+"°":"--",350,577);
  label("ACC "+v(thetaAccel,1)+"°   GYRO "+v(thetaGyro,1)+"°   FLEX RAW "+flexADC+" ADC",65,636);
  label("FSR THUMB "+thumbADC+"   INDEX "+indexADC+"    SIGN "+(gyroSign>0?"+1":"-1"),65,672);
  anglePlot(678,176,560,219,false);
  anglePlot(678,410,560,219,true);
  fill(0);textSize(25);text(motionLabel(),686,668);
  long current=inMotion?motionStart:stillStart;
  label("STATE "+(current<0?"--":ms(Math.max(0L,sensorMs-current)))+
      "   |   LAST MOTION "+ms(lastMotionMs)+"   |   COMPLETED "+motionCount,686,700);
  button("HOME",42,730,170,48,false);
  button("FLIP GYRO SIGN",234,730,217,48,false);
}
// ---------------------------------------------------------------------------
// Restituisce una scritta immediata: IN MOTION o STANDING STILL (o errore).
String motionLabel() {
  if(uiPreview)return inMotion?"IN MOTION":"STANDING STILL";
  if(!fresh())return "STREAM LOST";
  if(!imuReady)return "CALIBRATE MPU";
  if(imuResyncPending)return "MPU RE-SYNC: HOLD STILL";
  return inMotion?"IN MOTION":"STANDING STILL";
}

// ---------------------------------------------------------------------------
// FSR UI: dimensione proporzionale all’ADC; rosso sotto range, verde dentro, giallo sopra.
// L’ADC non e espresso in Newton: non equivale a una forza calibrata.
void pressureCircle(float x,float y,int adc,String name) {
  float fraction=constrain(adc/1023.0,0,1);
  float diameter=19+55*fraction;
  int rgb=adc<FSR_TARGET_MIN_ADC?color(211,57,57):
          adc<=FSR_TARGET_MAX_ADC?color(31,158,74):color(214,147,35);
  noStroke();fill(rgb);ellipse(x,y,diameter,diameter); // nessun bordo, cerchio pieno colorato
  fill(55);textAlign(CENTER,BASELINE);textSize(12);
  text(name+" "+adc,x,y+52);
  textAlign(LEFT,BASELINE);
}
// ---------------------------------------------------------------------------
// Traduzione dello stato interno nella grande scritta di Assessment/Training.
String phaseText() {
  if(trialPhase==READY)return "READY";
  if(trialPhase==COUNTDOWN)return str(max(1,(int)Math.ceil((COUNTDOWN_MS-(millis()-countdownStarted))/1000.0)));
  if(trialPhase==WAIT_START)return "GO!";
  if(trialPhase==REACH)return "GO!";
  if(trialPhase==GRASP)return "HOLD GRASP";
  if(trialPhase==COMPLETE)return "COMPLETED";
  if(trialPhase==FAILED)return "RETRY";
  return "FINAL RESULTS";
}
// ---------------------------------------------------------------------------
// PAGINA UNICA di Assessment/Training: countdown, stato e due grafici affiancati.
// Training aggiunge la barra di tempo; entrambi condividono il detector.
void drawTrialPage() {
  boolean train=page==TRAIN;
  ArrayList<Trial> trials=train?training:assessment;
  if(trialPhase==RESULTS) {drawTrialResults(trials,train);return;}
  heading(train?"TRAINING":"ASSESSMENT",
     train?"Timed reaching with adaptive difficulty. Reach and hold an object; no arm model is required.":
           "Five guided reaching trials. Fixed-angle plots, measured joint angles, and optional FSR grasp.");
  panel(42,128,1216,108);
  fill(0);textSize(45);text(phaseText(),64,193);
  textAlign(RIGHT,BASELINE);textSize(35);
  text(motionLabel(),1237,184);
  textAlign(LEFT,BASELINE);
  label("TRIAL "+(trials.size()+(trialPhase==COMPLETE?0:1))+" / "+(train?TRAINING_TRIALS:ASSESSMENT_TRIALS),65,219);
  if(train) {
    float elapsed=(trialPhase==WAIT_START || trialPhase==REACH || trialPhase==GRASP ||
                   trialPhase==COMPLETE)?max(0,(sensorMs-trialGoSensor)/1000.0):0;
    if((trialPhase==GRASP || trialPhase==COMPLETE) && reachEnd>=0)
      elapsed=max(0,(reachEnd-trialGoSensor)/1000.0);
    float progress=constrain(elapsed/max(0.1,trainTargetS),0,1);
    fill(60);textSize(13);text("TARGET "+sec(trainTargetS)+"  •  elapsed "+sec(elapsed),540,217);
    stroke(0);noFill();rect(895,205,338,13);
    noStroke();fill(0);rect(895,205,338*progress,13);
    if((trialPhase==WAIT_START || trialPhase==REACH) && elapsed>trainTargetS) {
      fill(190,54,43);textSize(14);text("TOO SLOW",790,218);
    }
  }
  anglePlot(42,251,595,341,false);
  anglePlot(655,251,603,341,true);
  panel(42,606,1216,131);
  label("REACTION TIME",62,631);
  number(reachStart>=0?ms(Math.max(0L,reachStart-trialGoSensor)):"--",62,668);
  label("MOVEMENT DURATION",280,631);
  float movingTime=reachStart<0?Float.NaN:
    (reachEnd>=0?(reachEnd-reachStart)/1000.0:(sensorMs-reachStart)/1000.0);
  number(sec(movingTime),280,668);
  if(FSR_ENABLED) {
    label("FSR: BOTH CIRCLES GREEN FOR "+v(GRASP_HOLD_MS/1000.0,1)+" s",550,627);
    pressureCircle(667,677,thumbADC,"THUMB");
    pressureCircle(769,677,indexADC,"INDEX");
    if(trialPhase==GRASP)label("HOLD "+ms(graspStarted<0?0:sensorMs-graspStarted),849,686);
  } else label("FSR DISABLED — MOTION-ONLY TEST",550,664);
  if(trialPhase==COMPLETE || trialPhase==FAILED) {
    fill(0);textSize(15);text(trialFeedback,62,716);
  }
  if(trialPhase==READY)button("START",1059,674,177,47,true);
  else if(trialPhase==COMPLETE)button("NEXT TRIAL",1035,674,201,47,true);
  else if(trialPhase==FAILED)button("RETRY",1059,674,177,47,true);
  else button("RUNNING",1059,674,177,47,false);
  button("HOME",42,746,165,40,false);
  if(trialPhase==COMPLETE)button("RETRY THIS",225,746,160,40,false);
  if(uiPreview)button("SEE RESULTS",431,746,177,40,false); // Solo per testare il layout finale.
}
// ---------------------------------------------------------------------------
// Risultati finali: medie, SD e tabella di tutti i reaching.
void drawTrialResults(ArrayList<Trial> trials,boolean train) {
  heading("FINAL RESULTS — "+(train?"TRAINING":"ASSESSMENT"),
          trials.size()+" completed trials. Means and standard deviations use measured, unsmoothed data.");
  float[] yy={141,236};
  String[] names={"MEAN MOVEMENT DURATION","MEAN REACTION TIME","MEAN SHOULDER EXCURSION",
                  "MEAN ELBOW EXTENSION"};
  int[] metrics={0,3,1,2};
  for(int i=0;i<4;i++) {
    float x=42+i*310;
    panel(x,142,284,118);
    label(names[i],x+13,173);
    number(v(averageTrial(trials,metrics[i]),2)+(i<2?" s":"°"),x+13,215);
    label("SD "+v(sdTrial(trials,metrics[i]),2)+(i<2?" s":"°"),x+13,242);
  }
  panel(42,279,1216,440);
  String[] h={"TRIAL","REACTION","MOVEMENT","SH MAX","SH Δ","EL MIN","EL EXT","FEEDBACK"};
  int[] xx={62,170,313,464,610,751,896,1039};
  fill(0);textSize(13);
  for(int i=0;i<h.length;i++)text(h[i],xx[i],309);
  stroke(180);line(60,321,1236,321);
  for(int i=0;i<trials.size();i++) {
    Trial t=trials.get(i);
    int y=346+i*(train?31:52);
    fill(0);textSize(14);
    text(str(i+1),xx[0],y);
    text(sec(t.reactionS),xx[1],y);
    text(sec(t.movementS),xx[2],y);
    text(v(t.shoulderMaximum,1)+"°",xx[3],y);
    text(v(t.shoulderExcursion,1)+"°",xx[4],y);
    text(v(t.elbowMinimum,1)+"°",xx[5],y);
    text(v(t.elbowExtension,1)+"°",xx[6],y);
    text(t.feedback,xx[7],y);
  }
  if(FSR_ENABLED) {
    int stable=0;float holdSum=0;
    for(Trial t:trials)if(t.graspValid){stable++;holdSum+=t.graspS;}
    label("FSR STABLE GRASPS "+stable+" / "+trials.size()+
          "   |   MEAN TIME TO STABLE GRASP "+(stable>0?sec(holdSum/stable):"--"),61,697);
  } else label(train?"Latest completed Assessment is the Training reference; target adapts every two trials.":
        "Assessment saved locally. Green angles are visual references, not mandatory success thresholds.",
        61,697);
  button("HOME",42,738,170,46,false);
  button("NEW SESSION",228,738,220,46,true);
}

// ---------------------------------------------------------------------------
// UI DEL GIOCO: braccio 2D + pallina rossa nel workspace raggiungibile.
void drawGame() {
  if(gamePhase==GAME_RESULTS) {drawGameResults();return;}
  heading("TARGET TRACKING GAME",
          "Move the virtual wrist to the red target. Partial overlap is enough; all targets are generated inside the arm workspace.");
  panel(42,129,839,593);panel(896,129,362,593);
  float originX=222,originY=229;
  float scale=400;
  stroke(220);strokeWeight(1);line(originX,170,originX,660);
  fill(90);textSize(12);text("SHOULDER",originX-35,180);
  if(gamePhase!=GAME_READY) {
    drawArm(originX,originY,scale);
    float[] tgt=currentGameTarget();
    if(gamePhase==GAME_STATIC && millis()<gameTargetHost) {
      fill(0);textSize(21);text("NEW TARGET",495,184);
    } else {
      float px=originX+scale*tgt[0],py=originY+scale*tgt[1];
      noStroke();fill(218,44,44,45);
      ellipse(px,py,2*GAME_TARGET_RADIUS_M*scale+10,2*GAME_TARGET_RADIUS_M*scale+10);
      fill(215,39,39);
      ellipse(px,py,2*GAME_TARGET_RADIUS_M*scale,2*GAME_TARGET_RADIUS_M*scale);
      if(gamePhase==GAME_TRACK) {
        float x1=originX+scale*trackStart[gameTrackIndex][0];
        float y1=originY+scale*trackStart[gameTrackIndex][1];
        float x2=originX+scale*trackEnd[gameTrackIndex][0];
        float y2=originY+scale*trackEnd[gameTrackIndex][1];
        stroke(215,39,39,100);strokeWeight(1.5);
        line(x1,y1,x2,y2);
      }
    }
  } else {
    fill(0);textSize(27);text("READY TO PLAY",100,236);
    fill(75);textSize(17);
    text("6 static targets + horizontal and diagonal tracking.",99,283);
    text("Each wrist target is calculated from the 2-joint model.",99,319);
  }
  if(gamePhase==GAME_STATIC) {
    number("STATIC TARGET "+(gameStaticIndex+1)+" / "+GAME_STATIC_COUNT,919,186);
    label("Touch the red ball with the virtual hand",919,233);
    label("A brief overlap is enough",919,259);
    label("HITS",919,328);number(str(gameHits),919,368);
    label("ELAPSED",919,435);
    number(sec(max(0,millis()-gameTargetHost)/1000.0),919,472);
  } else if(gamePhase==GAME_TRACK) {
    number(gameTrackIndex==0?"HORIZONTAL":"DIAGONAL",919,184);
    label("Follow the moving target",919,225);
    label("TIME REMAINING",919,316);
    number(sec(max(0,GAME_TRACK_MS-(millis()-gamePhaseHost))/1000.0),919,357);
    label("TIME ON TARGET",919,432);
    number(trackTotalTimeMs>0?v(100*trackOnTimeMs/trackTotalTimeMs,1)+"%":"--",919,470);
  } else {
    number("START GAME",919,186);
    label("Arm length: "+v(UPPER_ARM_M,2)+" m",919,243);
    label("Forearm length: "+v(FOREARM_M,2)+" m",919,276);
    label("Assessment ROM: "+(GAME_USE_ASSESSMENT_ROM && completedAssessment.size()==ASSESSMENT_TRIALS?"ON":"NOT AVAILABLE"),919,309);
  }
  if(uiPreview) {
    label("PREVIEW CONTROLS: LEFT/RIGHT = SHOULDER",919,527);
    label("UP/DOWN = ELBOW",919,550);
    button("SEE RESULTS",929,563,284,42,false);
  }
  label("CURRENT SHOULDER  "+v(thetaFused,1)+"°     ELBOW  "+v(elbowDeg,1)+"°",100,686);
  if(gamePhase==GAME_READY)button("START",929,617,284,52,true);
  button("HOME",42,741,170,46,false);
}
// ---------------------------------------------------------------------------
// Risultati gioco: response time, error di inseguimento, tempo nel target.
void drawGameResults() {
  heading("FINAL RESULTS — TARGET GAME", "Six static targets and two dynamic paths. Distances are computed from measured, not displayed, joint angles.");
  String[] n={"STATIC TARGETS REACHED","MEAN RESPONSE TIME",
              "MEAN TRACKING ERROR","MEAN TIME ON TARGET"};
  String[] val={gameHits+" / "+GAME_STATIC_COUNT,sec(meanResponse()),
                 v(100*meanTrackError(),1)+" cm",v(meanTrackOn(),1)+"%"};
  for(int i=0;i<4;i++) {
    float x=42+i*309;
    panel(x,148,286,120);
    label(n[i],x+14,185);number(val[i],x+14,235);
  }
  panel(42,290,1216,412);
  fill(0);textSize(18);text("STATIC TARGETS",65,329);
  for(int i=0;i<GAME_STATIC_COUNT;i++) {
    fill(50);textSize(16);
    text("TARGET "+(i+1)+"   "+(staticSucceeded[i]==1?sec(staticResponse[i]):"NOT REACHED"),
         65+(i/3)*575,380+(i%3)*61);
  }
  stroke(190);line(65,561,1223,561);
  fill(0);textSize(18);text("TRACKING",65,595);
  for(int i=0;i<2;i++) {
    fill(70);textSize(15);
    text((i==0?"HORIZONTAL":"DIAGONAL")+"   Mean error "+v(trackMeanError[i]*100,1)+
         " cm   |   On target "+v(trackOnPercent[i],1)+"%",65,637+i*33);
  }
  button("HOME",42,735,170,48,false);
  button("PLAY AGAIN",230,735,205,48,true);
}
// ---------------------------------------------------------------------------
// Media errore del tracking dei due percorsi mobili [m].
float meanTrackError() {
  if(Float.isNaN(trackMeanError[0]) || Float.isNaN(trackMeanError[1]))return Float.NaN;
  return (trackMeanError[0]+trackMeanError[1])/2;
}
// ---------------------------------------------------------------------------
// Media della percentuale di tempo nel target nei due tracking.
float meanTrackOn() {return (trackOnPercent[0]+trackOnPercent[1])/2;}



// ==========================================================================
// TAB: Controls.pde
// ==========================================================================
// ==========================================================================
// MOUSE INPUT — simple buttons, no hidden modes
// ==========================================================================
// ---------------------------------------------------------------------------
// Hit-test di un bottone: controlla se mouseX/mouseY sono nel rettangolo.
boolean hit(float x,float y,float w,float h) {
  return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h;
}
// ---------------------------------------------------------------------------
// CLICK HANDLER: naviga la GUI e lancia le funzioni di stato senza schermate extra.
void mousePressed() {
  if(page==HOME) { // mousePressed: il significato del click dipende dalla pagina corrente
    if(hit(59,292,164,47)) {page=FLEX;flexPhase=0;return;}
    if(hit(242,292,168,47)) {page=IMU;imuPhase=0;return;}
    if(hit(457,139,386,220)) {page=LIVE;resetMotion();return;}
    if(hit(872,139,386,220)) {openMode(ASSESS);return;}
    if(hit(42,385,593,220)) {openMode(TRAIN);return;}
    if(hit(663,385,595,220)) {openGame();return;}
  } else if(page==FLEX) {
    if(hit(42,730,200,48)) {if(flexPhase==0)startFlex();else stopFlex();return;}
    if(hit(266,730,170,48)) {flexPhase=0;leaveUiPreview();page=HOME;return;}
  } else if(page==IMU) {
    if(hit(42,730,200,48) && imuPhase!=1) {startImu();return;}
    if(hit(266,730,170,48)) {imuPhase=0;leaveUiPreview();page=HOME;return;}
  } else if(page==LIVE) {
    if(hit(42,730,170,48)) {leaveUiPreview();page=HOME;return;}
    if(hit(234,730,217,48)) {
      gyroSign=-gyroSign;
      if(imuReady && !Float.isNaN(thetaAccel)) {
        thetaFused=thetaAccel;thetaGyro=thetaAccel;
        previousImuMs=-1;
      }
      saveCalibration();
      notice="Gyro sign changed. Raise arm slowly; ACC and FUSED should increase together.";
      return;
    }
  } else if(page==ASSESS || page==TRAIN) {
    if(uiPreview && trialPhase!=RESULTS && hit(431,746,177,40)) {
      showPreviewResults();return; // Solo anteprima; risultati dimostrativi.
    }
    if(trialPhase==RESULTS) {
      if(hit(42,738,170,46)) {leaveUiPreview();page=HOME;return;}
      if(hit(228,738,220,46)) {openMode(page);return;}
    } else {
      if(hit(42,746,165,40)) {leaveUiPreview();page=HOME;return;}
      if(trialPhase==COMPLETE && hit(225,746,160,40)) {
        ArrayList<Trial> results=page==ASSESS?assessment:training;
        if(results.size()>0) {
          Trial removed=results.remove(results.size()-1);
          if(page==TRAIN)trainTargetS=removed.targetS; // undo latest pair adaptation
        }
        beginCountdown();return;
      }
      if(hit(1035,674,201,47)) {
        if(trialPhase==READY || trialPhase==FAILED)beginCountdown();
        else if(trialPhase==COMPLETE) {
          ArrayList<Trial> results=page==ASSESS?assessment:training;
          int goal=page==ASSESS?ASSESSMENT_TRIALS:TRAINING_TRIALS;
          if(results.size()>=goal) {
            trialPhase=RESULTS;
            if(page==ASSESS && !uiPreview)saveAssessmentResults(); // Mai salvare risultati fittizi.
          } else beginCountdown();
        }
        return;
      }
    }
  } else if(page==GAME) {
    if(uiPreview && gamePhase!=GAME_RESULTS && hit(929,563,284,42)) {
      showPreviewResults();return;
    }
    if(hit(42,741,170,46)) {leaveUiPreview();page=HOME;return;}
    if(gamePhase==GAME_READY && hit(929,617,284,52)) {startGame();return;}
    if(gamePhase==GAME_RESULTS && hit(230,735,205,48)) {startGame();return;}
  }
}

// Persist the most recent *completed* assessment so Training can reuse it.
// ---------------------------------------------------------------------------
// Salva su JSON SOLO un Assessment completo: e la baseline dei Training futuri.
void saveAssessmentResults() {
  if(assessment.size()!=ASSESSMENT_TRIALS)return;
  completedAssessment.clear();
  completedAssessment.addAll(assessment);
  try {
    JSONObject j=new JSONObject();
    j.setInt("version",1);
    JSONArray a=new JSONArray();
    for(Trial t:assessment) {
      JSONObject r=new JSONObject();
      r.setFloat("reaction",t.reactionS);r.setFloat("movement",t.movementS);
      r.setFloat("shInitial",t.initialShoulder);r.setFloat("elInitial",t.initialElbow);
      r.setFloat("shMax",t.shoulderMaximum);r.setFloat("shROM",t.shoulderExcursion);
      r.setFloat("elMin",t.elbowMinimum);r.setFloat("elROM",t.elbowExtension);
      a.append(r);
    }
    j.setJSONArray("trials",a);
    saveJSONObject(j,sketchPath("reach_grasp_assessment.json"));
  } catch(Exception e) {notice="Assessment results could not be saved.";}
}
// ---------------------------------------------------------------------------
// Ricarica i 5 trial salvati per usare il tempo/ROM come riferimento iniziale.
void loadAssessmentResults() {
  java.io.File f=new java.io.File(sketchPath("reach_grasp_assessment.json"));
  if(!f.exists())return;
  try {
    JSONObject j=loadJSONObject(f.getAbsolutePath());
    JSONArray a=j.getJSONArray("trials");
    if(a==null || a.size()!=ASSESSMENT_TRIALS)return;
    completedAssessment.clear();
    for(int i=0;i<a.size();i++) {
      JSONObject r=a.getJSONObject(i);
      completedAssessment.add(new Trial(r.getFloat("reaction"),r.getFloat("movement"),
        r.getFloat("shInitial"),r.getFloat("elInitial"),r.getFloat("shMax"),
        r.getFloat("shROM"),r.getFloat("elMin"),r.getFloat("elROM"),
        Float.NaN,false,Float.NaN,"SAVED"));
    }
  } catch(Exception e) {completedAssessment.clear();}
}


// ==========================================================================
// TAB: Preview.pde
// ==========================================================================
// ============================================================================
// UI PREVIEW — nessun sensore necessario; logica reale NON modificata.
// I dati inventati servono solo a provare i layout e i pulsanti.
// ============================================================================

// Si puo entrare normalmente con sensori pronti; altrimenti si apre l'anteprima.
void enterUiPreview() {
  if(uiPreview)return;
  uiPreview=true;
  realSensorMsBeforePreview=sensorMs;
  realElbowBeforePreview=elbowDeg;
  realAccelBeforePreview=thetaAccel;
  realGyroBeforePreview=thetaGyro;
  realFusedBeforePreview=thetaFused;
  previewLastSample=-100000;
  previewOnsetSent=false;previewEndSent=false;
  plotHead=0;plotN=0;
  notice="UI PREVIEW: dati simulati, nessun risultato o calibrazione salvati.";
}

// Ripristina i valori reali e la connessione: l'anteprima non altera la calibrazione.
void leaveUiPreview() {
  if(!uiPreview)return;
  uiPreview=false;
  sensorMs=realSensorMsBeforePreview;
  elbowDeg=realElbowBeforePreview;
  thetaAccel=realAccelBeforePreview;
  thetaGyro=realGyroBeforePreview;
  thetaFused=realFusedBeforePreview;
  displayElbow=Float.NaN;displayShoulder=Float.NaN;
  plotHead=0;plotN=0;
  previousImuMs=-1; // Al prossimo pacchetto riparte senza integrare il vuoto temporale.
  resetMotion();
}

// In anteprima sostituisce l'ingresso sensori SOLTANTO nelle tre modalita.
boolean canRunActivity() {
  return uiPreview || readySensors();
}

// Genera un campione ogni 40 ms. Assessment/Training simulano un reaching completo;
// nel Game le frecce modificano gli angoli della mano virtuale.
void tickUiPreview() {
  if(!uiPreview)return;
  int now=millis();
  if(now-previewLastSample<PREVIEW_SAMPLE_MS)return;
  previewLastSample=now;
  sensorMs=now;
  movementStartedEvent=false;movementEndedEvent=false;
  float sh=2,el=90; // Posa iniziale simulata, in gradi.
  inMotion=false;

  if(page==ASSESS || page==TRAIN) {
    if(trialPhase==WAIT_START || trialPhase==REACH || trialPhase==GRASP || trialPhase==COMPLETE) {
      int elapsed=now-(int)trialGoHost;
      float u=constrain((elapsed-PREVIEW_REACTION_MS)/(float)PREVIEW_REACH_MS,0,1);
      float s=u*u*(3-2*u); // Smoothstep: movimento fittizio non a scatti.
      sh=2+83*s;el=90-83*s;
      inMotion=(u>0 && u<1);
      if(!previewOnsetSent && elapsed>=PREVIEW_REACTION_MS+ON_CONFIRM_MS) {
        previewOnsetSent=true;
        movementStartedEvent=true;
        eventOnset=trialGoSensor+PREVIEW_REACTION_MS; // Onset retrodatato.
      }
      if(!previewEndSent && elapsed>=PREVIEW_REACTION_MS+PREVIEW_REACH_MS+OFF_CONFIRM_MS) {
        previewEndSent=true;
        movementEndedEvent=true;
        eventOffset=trialGoSensor+PREVIEW_REACTION_MS+PREVIEW_REACH_MS;
      }
    }
    // Con FSR_ENABLED=true simuliamo anche il contatto e una presa stabile.
    thumbADC=(FSR_ENABLED && (trialPhase==GRASP || trialPhase==COMPLETE))?400:0;
    indexADC=(FSR_ENABLED && (trialPhase==GRASP || trialPhase==COMPLETE))?410:0;
  } else if(page==GAME) {
    sh=previewGameShoulder;
    el=previewGameElbow;
  }
  thetaFused=sh;thetaAccel=sh;thetaGyro=sh;elbowDeg=el;
  plotT[plotHead]=sensorMs;
  plotElbow[plotHead]=elbowDeg;
  plotShoulder[plotHead]=thetaFused;
  plotHead=(plotHead+1)%HISTORY;
  plotN=min(HISTORY,plotN+1);
  // Stessi algoritmi delle modalita reali, ma alimentati da dati fittizi.
  if(page==ASSESS || page==TRAIN)onTrialSample(sensorMs);
  if(page==GAME)onGameSample(sensorMs);
}

// Anteprima risultati in un click: numeri di ESEMPIO, mai scritti nel JSON.
void showPreviewResults() {
  if(!uiPreview)return;
  if(page==ASSESS || page==TRAIN) {
    ArrayList<Trial> list=page==ASSESS?assessment:training;
    list.clear();
    int n=page==ASSESS?ASSESSMENT_TRIALS:TRAINING_TRIALS;
    for(int i=0;i<n;i++) {
      float reaction=0.38+0.04*(i%3);
      float move=1.95+0.06*(i%4);
      float shROM=79+2*(i%3),elROM=81-2*(i%3);
      list.add(new Trial(reaction,move,2,90,2+shROM,shROM,90-elROM,elROM,
                         Float.NaN,false,page==TRAIN?trainTargetS:Float.NaN,
                         page==TRAIN?"ON TIME":"COMPLETED"));
    }
    trialPhase=RESULTS;
  } else if(page==GAME) {
    gameHits=GAME_STATIC_COUNT;
    for(int i=0;i<GAME_STATIC_COUNT;i++) {
      staticSucceeded[i]=1;
      staticResponse[i]=1.30+0.11*(i%3);
    }
    trackMeanError[0]=0.035;trackMeanError[1]=0.041;
    trackOnPercent[0]=71;trackOnPercent[1]=64;
    gamePhase=GAME_RESULTS;
  }
}

// Solo in anteprima del GAME: frecce orizzontali = spalla,
// frecce verticali = gomito. Gli angoli rimangono nei limiti del gioco.
void keyPressed() {
  if(!uiPreview || page!=GAME || gamePhase==GAME_RESULTS || key!=CODED)return;
  if(keyCode==LEFT)previewGameShoulder-=PREVIEW_KEY_STEP_DEG;
  if(keyCode==RIGHT)previewGameShoulder+=PREVIEW_KEY_STEP_DEG;
  if(keyCode==UP)previewGameElbow-=PREVIEW_KEY_STEP_DEG;
  if(keyCode==DOWN)previewGameElbow+=PREVIEW_KEY_STEP_DEG;
  float sMin=gamePhase==GAME_READY?GAME_SHOULDER_MIN_DEG:gameShMin;
  float sMax=gamePhase==GAME_READY?GAME_SHOULDER_MAX_DEG:gameShMax;
  float eMin=gamePhase==GAME_READY?GAME_ELBOW_MIN_DEG:gameElMin;
  float eMax=gamePhase==GAME_READY?GAME_ELBOW_MAX_DEG:gameElMax;
  previewGameShoulder=constrain(previewGameShoulder,sMin,sMax);
  previewGameElbow=constrain(previewGameElbow,eMin,eMax);
}
