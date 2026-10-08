import processing.serial.*;
import java.util.ArrayList;

// Independent, simple live-data acquisition for the original pre-AI UI.
Serial preAIPort;
String preAIPortName = "";
boolean preAILeadsOff = false;
int preAILastPacket = 0;
ArrayList<Float> ecgPreAI = new ArrayList<Float>();
ArrayList<Float> fsrPreAI = new ArrayList<Float>();
final int PRE_AI_PLOT_LIMIT = 300;
int preAIPlotDecimation = 0;
float preAIEcgBaseline = 0;
float preAIFsrBaseline = 0;
float preAIPreviousEcg = 0;
float preAIPreviousFsr = 0;
int preAILastBeat = 0;
int preAILastBreath = 0;
int preAIInhaleStart = 0;
int preAIExhaleStart = 0;
boolean preAIInhaling = false;

void setupPreAILiveData() {
  String[] ports = Serial.list();
  println("Available serial ports:");
  printArray(ports);
  if (ports.length == 0) {
    println("No serial ports. Connect FireBeetle and restart Processing.");
    return;
  }
  // Prefer a USB serial device; use COM3 for Stefano's Windows setup.
  String selected = null;
  for (String port : ports) {
    if (port.equals("COM3")) { selected = port; break; }
  }
  if (selected == null) {
    for (String port : ports) {
      if (port.contains("usbmodem") || port.contains("usbserial") ||
          port.contains("wchusbserial") || port.contains("SLAB_USBtoUART")) {
        selected = port;
        break;
      }
    }
  }
  if (selected == null) {
    println("No recognized FireBeetle serial port. Available: " + join(ports, ", "));
    return;
  }
  try {
    preAIPort = new Serial(this, selected, 115200);
    preAIPort.clear();
    preAIPort.bufferUntil('\n');
    preAIPortName = selected;
  } catch (Exception e) {
    println("Cannot open " + selected + ": " + e.getMessage());
  }
}

void serialEvent(Serial port) {
  if (port != preAIPort) return;
  String line = port.readStringUntil('\n');
  if (line == null) return;
  line = trim(line);
  if (line.equals("!")) { preAILeadsOff = true; return; }
  String[] fields = split(line, ',');
  if (fields.length != 2) return;
  int ecg, fsr;
  try {
    ecg = Integer.parseInt(trim(fields[0]));
    fsr = Integer.parseInt(trim(fields[1]));
  } catch (Exception e) { return; }
  if (ecg < 0 || ecg > 4095 || fsr < 0 || fsr > 4095) return;
  preAILeadsOff = false;
  preAILastPacket = millis();
  preAIEcgBaseline = preAIEcgBaseline * 0.995 + ecg * 0.005;
  float centered = ecg - preAIEcgBaseline;
  preAIFsrBaseline = preAIFsrBaseline * 0.99 + fsr * 0.01;
  float centeredFsr = fsr - preAIFsrBaseline;
  preAIPlotDecimation++;
  if (preAIPlotDecimation >= 5) {
    preAIPlotDecimation = 0;
    ecgPreAI.add(centered);
    fsrPreAI.add((float) fsr);
    if (ecgPreAI.size() > PRE_AI_PLOT_LIMIT) ecgPreAI.remove(0);
    if (fsrPreAI.size() > PRE_AI_PLOT_LIMIT) fsrPreAI.remove(0);
  }
  // Simple illustrative pre-AI threshold detector. Validate against real sensor.
  if (!preAILeadsOff && preAIPreviousEcg <= 35 && centered > 35 &&
      (preAILastBeat == 0 || millis() - preAILastBeat > 300)) {
    if (preAILastBeat > 0) {
      int dt = millis() - preAILastBeat;
      if (dt >= 300 && dt <= 2000) heartRate = round(60000.0 / dt);
    }
    preAILastBeat = millis();
  }
  preAIPreviousEcg = centered;
  // Breathing is approximated by crossings of the FSR trend.
  if (preAIPreviousFsr <= 2 && centeredFsr > 2 &&
      (preAILastBreath == 0 || millis() - preAILastBreath > 1500)) {
    if (preAILastBreath > 0) {
      int dt = millis() - preAILastBreath;
      if (dt >= 1500 && dt <= 15000) respRate = 60000.0 / dt;
    }
    if (preAIExhaleStart > 0) exhaleTime = (millis() - preAIExhaleStart) / 1000.0;
    preAIInhaleStart = millis();
    preAIInhaling = true;
    preAILastBreath = millis();
  } else if (preAIInhaling && preAIPreviousFsr >= -2 && centeredFsr < -2) {
    if (preAIInhaleStart > 0) inhaleTime = (millis() - preAIInhaleStart) / 1000.0;
    preAIExhaleStart = millis();
    preAIInhaling = false;
  }
  preAIPreviousFsr = centeredFsr;
}

void drawPreAIConnectionStatus() {
  fill(0);
  textSize(12);
  String status = preAIPort == null ? "NO SERIAL DEVICE" :
    preAILeadsOff ? "ECG LEADS OFF" :
    millis() - preAILastPacket > 2500 ? "WAITING FOR SENSOR DATA" :
    "LIVE: " + preAIPortName;
  text(status, 680, 100);
}

void drawLivePreAIWaveform(ArrayList<Float> samples, float left, float top,
                           float right, float bottom, int lineColor) {
  if (samples.size() < 2) return;
  float low = Float.MAX_VALUE;
  float high = -Float.MAX_VALUE;
  for (float v : samples) { low = min(low, v); high = max(high, v); }
  float padding = max(2, (high - low) * 0.15);
  low -= padding;
  high += padding;
  stroke(lineColor);
  noFill();
  beginShape();
  for (int i = 0; i < samples.size(); i++) {
    float x = map(i, 0, PRE_AI_PLOT_LIMIT - 1, left, right);
    float y = constrain(map(samples.get(i), low, high, bottom, top), top, bottom);
    vertex(x, y);
  }
  endShape();
}
