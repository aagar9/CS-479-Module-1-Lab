// Compatibility adapter for the simple pre-AI interface.
// Signal calculations are copied from the post-AI sketch.
String preAIPortName = "";
int preAILastPacket = 0;
ArrayList<Float> ecgPreAI = ecgPlot;
ArrayList<Float> fsrPreAI = fsrPlot;
final int PRE_AI_PLOT_LIMIT = 500;

void drawPreAIConnectionStatus() {
  fill(0);
  textSize(12);
  String status = myPort == null ? "NO SERIAL DEVICE" :
    leadsOff ? "ECG LEADS OFF" :
    millis() - preAILastPacket > 2500 ? "WAITING FOR SENSOR DATA" :
    "LIVE: " + preAIPortName;
  text(status, 680, 100);
}

void drawLivePreAIWaveform(ArrayList<Float> samples, float left, float top,
                           float right, float bottom, int lineColor) {
  if (samples.size() < 2) return;
  float low = Float.MAX_VALUE, high = -Float.MAX_VALUE;
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
