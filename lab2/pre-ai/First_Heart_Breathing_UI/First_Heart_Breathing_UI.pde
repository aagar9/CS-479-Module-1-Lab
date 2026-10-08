// Lab 2 pre-AI: basic interface; live sensor calculations stay in PreAI_LiveData.pde.
// Use mouse buttons to enter modes and start the required 30-second baselines.
int mode = 0;
int heartRate = 0;
float respRate = 0, inhaleTime = 0, exhaleTime = 0;
int stage = 0;  // 0=ready, 1=baseline, 2=live, 3=relaxing, 4=task
int startedAt = 0, lastSampleAt = 0;
float sumHR = 0, sumRR = 0, baseHR = 0, baseRR = 0;
int countHR = 0, countRR = 0;
int age = 22, lastZoneAt = 0, lastZone = -1;
float[] zoneRR = new float[5], zoneIn = new float[5], zoneEx = new float[5];
int[] zoneCount = new int[5];
java.util.ArrayList<Integer> zoneHistory = new java.util.ArrayList<Integer>();
int lastHistoryAt = 0;
float stressRelaxHR = 0, stressRelaxRR = 0, stressTaskHR = 0, stressTaskRR = 0;
int badBreaths = 0;
float lastBreathIn = -1, lastBreathEx = -1;
String status = "WAITING";
String[] zones = {"VERY LIGHT", "LIGHT", "MODERATE", "HARD", "MAXIMUM"};

void setup() {
  size(1000, 700);
  setupSignalProcessing();
  textFont(createFont("Arial", 15));
}
void draw() {
  heartRate = BPM;
  respRate = respiratoryRate;
  inhaleTime = Tinsp / 1000.0;
  exhaleTime = Tex / 1000.0;
  background(250);
  fill(0); textSize(27); text("Heart + Breathing Monitor", 25, 42);
  navButton(25, 65, "HOME", 0);
  navButton(170, 65, "FITNESS", 1);
  navButton(315, 65, "STRESS", 2);
  navButton(460, 65, "MEDITATION", 3);
  drawPreAIConnectionStatus();
  if (stage == 1) updateBaseline();
  if (mode == 1 && stage == 2) updateFitness();
  if (mode == 3 && stage == 2) updateMeditation();
  if (mode == 2 && (stage == 3 || stage == 4)) updateStressSamples();
  fill(0); textSize(22);
  text(mode == 0 ? "HOME" : mode == 1 ? "FITNESS" : mode == 2 ? "STRESS" : "MEDITATION", 30, 155);
  textSize(16);
  text("HR: " + heartRate + " BPM     RR: " + nf(respRate,0,1) + "/min     Inhale: " +
       nf(inhaleTime,0,1) + " s     Exhale: " + nf(exhaleTime,0,1) + " s", 30, 190);
  if (mode == 0) {
    text("Select a mode above. Connect the FireBeetle for live measurements.",30,245);
    graph(30,285,440,155,ecgPreAI,"ECG",color(210,40,40));
    graph(510,285,440,155,fsrPreAI,"RESPIRATION",color(40,80,210));
    return;
  }
  if (stage == 0) {
    text("Collect a 30-second resting baseline before starting.",30,240);
    button(30,275,240,"START BASELINE");
  } else if (stage == 1) {
    int remaining = max(0,30-(millis()-startedAt)/1000);
    text("Sit quietly. Baseline: " + remaining + " seconds remaining",30,245);
    text("Valid HR samples: "+countHR+"     RR samples: "+countRR,30,280);
  } else {
    text("Resting HR: "+nf(baseHR,0,1)+" BPM     Resting RR: "+nf(baseRR,0,1)+"/min",30,235);
    if (mode == 1) drawFitnessDetails();
    if (mode == 2) drawStressDetails();
    if (mode == 3) drawMeditationDetails();
  }
  graph(30,480,440,155,ecgPreAI,"ECG",color(210,40,40));
  graph(510,480,440,155,fsrPreAI,"RESPIRATION",color(40,80,210));
}
void navButton(int x,int y,String label,int id) {
  fill(mode==id ? color(160,205,240) : color(220)); stroke(0); rect(x,y,130,42);
  fill(0); textSize(14); text(label,x+12,y+27);
}
void button(int x,int y,int w,String label) {
  fill(220); stroke(0); rect(x,y,w,44);
  fill(0); textSize(15); text(label,x+12,y+28);
}
void graph(int x,int y,int w,int h,java.util.ArrayList<Float> samples,String label,int ink) {
  stroke(80); noFill(); rect(x,y,w,h);
  fill(0); textSize(13); text(label,x+10,y+18);
  drawLivePreAIWaveform(samples,x+12,y+30,x+w-12,y+h-12,ink);
}
void beginBaseline() {
  stage=1; startedAt=millis(); lastSampleAt=0;
  sumHR=0; sumRR=0; countHR=0; countRR=0;
}
void updateBaseline() {
  int now=millis();
  if (now-lastSampleAt>=1000) {
    lastSampleAt=now;
    if (heartRate>0) {sumHR+=heartRate;countHR++;}
    if (respRate>0) {sumRR+=respRate;countRR++;}
  }
  if (now-startedAt>=30000) {
    if(countHR==0 || countRR==0) {
      stage=0; status="No valid HR/RR samples; retry baseline"; return;
    }
    baseHR=sumHR/countHR; baseRR=sumRR/countRR; stage=2;
    lastZoneAt=now; lastHistoryAt=now;
    zoneHistory.clear();
    for(int i=0;i<5;i++){zoneRR[i]=0;zoneIn[i]=0;zoneEx[i]=0;zoneCount[i]=0;}
    badBreaths=0;lastBreathIn=-1;lastBreathEx=-1;
  }
}
int fitnessZone() {
  if(heartRate<=0) return -1;
  float pct=100.0*heartRate/(220-age);
  if(pct<50)return -1;
  return constrain((int)((pct-50)/10),0,4);
}
void updateFitness() {
  int now=millis();
  if(now-lastZoneAt>=1000) {
    lastZoneAt=now;
    int z=fitnessZone();
    if(z>=0) {
      zoneRR[z]+=respRate;zoneIn[z]+=inhaleTime;zoneEx[z]+=exhaleTime;zoneCount[z]++;
    }
  }
  if(now-lastHistoryAt>=1000) {
    lastHistoryAt=now;zoneHistory.add(fitnessZone());
    if(zoneHistory.size()>150)zoneHistory.remove(0);
  }
}
int zoneColor(int z) {
  if(z==0)return color(150);
  if(z==1)return color(60,150,220);
  if(z==2)return color(40,160,90);
  if(z==3)return color(240,160,35);
  if(z==4)return color(215,45,55);
  return color(225);
}
void drawFitnessDetails() {
  int z=fitnessZone();
  text("Age: "+age+" (press +/- to adjust)    Max HR: "+(220-age),30,270);
  text("Cardio zone: "+(z<0?"BELOW 50% / NO DATA":zones[z]),30,300);
  text("Zone history (one colored bar per second):",30,333);
  for(int i=0;i<zoneHistory.size();i++) {
    fill(zoneColor(zoneHistory.get(i)));noStroke();
    rect(30+i*5,345,5,22);
  }
  fill(0);textSize(13);
  text("Zone        RR change       Inhale change       Exhale change",30,395);
  for(int i=0;i<5;i++){
    String delta=zoneCount[i]==0?"--":
      nf(zoneRR[i]/zoneCount[i]-baseRR,0,1)+" /min     "+
      nf(zoneIn[i]/zoneCount[i],0,1)+" s     "+
      nf(zoneEx[i]/zoneCount[i],0,1)+" s";
    text(zones[i]+": "+delta,30,415+i*13);
  }
}
void updateStressSamples() {
  int now=millis();
  if(now-lastSampleAt<1000)return;
  lastSampleAt=now;
  if(heartRate>0){sumHR+=heartRate;countHR++;}
  if(respRate>0){sumRR+=respRate;countRR++;}
}
void drawStressDetails() {
  text("Compare HR and RR during relaxing music and a difficult task.",30,275);
  if(stage==2)button(30,295,245,"START RELAXING MUSIC");
  if(stage==3) {
    text("RELAXING MUSIC: "+(millis()-startedAt)/1000+" s. Play music externally.",30,315);
    button(30,345,245,"END RELAXING PHASE");
  }
  if(stage==4) {
    text("DIFFICULT TASK: "+(millis()-startedAt)/1000+" s.",30,315);
    button(30,345,245,"END TASK");
  }
  text("Relaxed HR/RR: "+nf(stressRelaxHR,0,1)+" / "+nf(stressRelaxRR,0,1),330,325);
  text("Task HR/RR: "+nf(stressTaskHR,0,1)+" / "+nf(stressTaskRR,0,1),330,355);
  text("Interpretation: "+status,30,425);
  if(stage==2 && stressRelaxHR>0)button(30,350,245,"START DIFFICULT TASK");
}
void drawMeditationDetails() {
  text("Target: exhale duration = 3 x inhale duration.",30,280);
  text("Consecutive breaths outside target: "+badBreaths,30,325);
  fill(badBreaths>=3?color(210,30,30):color(30,130,60));
  textSize(22);text(badBreaths>=3?"ADJUST BREATHING":"KEEP BREATHING",30,380);
}
void updateMeditation() {
  if(inhaleTime<=0 || exhaleTime<=0)return;
  if(inhaleTime==lastBreathIn && exhaleTime==lastBreathEx)return;
  lastBreathIn=inhaleTime;lastBreathEx=exhaleTime;
  if(abs(exhaleTime-3*inhaleTime)<=0.3*3*inhaleTime)badBreaths=0;
  else badBreaths++;
}
void mousePressed() {
  if(mouseY>=65&&mouseY<=107) {
    int[] xs={25,170,315,460};
    for(int i=0;i<4;i++)if(mouseX>=xs[i]&&mouseX<=xs[i]+130) {
      mode=i;stage=0;status="WAITING";return;
    }
  }
  if(mode==0)return;
  if(stage==0&&mouseX>=30&&mouseX<=270&&mouseY>=275&&mouseY<=319) {
    beginBaseline();return;
  }
  if(mode==2&&stage==2&&mouseX>=30&&mouseX<=275&&mouseY>=295&&mouseY<=339) {
    stage=3;startedAt=millis();lastSampleAt=0;sumHR=0;sumRR=0;countHR=0;countRR=0;return;
  }
  if(mode==2&&stage==2&&stressRelaxHR>0&&mouseX>=30&&mouseX<=275&&mouseY>=350&&mouseY<=394) {
    stage=4;startedAt=millis();lastSampleAt=0;sumHR=0;sumRR=0;countHR=0;countRR=0;return;
  }
  if(mode==2&&stage==3&&mouseX>=30&&mouseX<=275&&mouseY>=345&&mouseY<=389) {
    stressRelaxHR=countHR>0?sumHR/countHR:0;stressRelaxRR=countRR>0?sumRR/countRR:0;stage=2;status="Relaxing phase complete";return;
  }
  if(mode==2&&stage==4&&mouseX>=30&&mouseX<=275&&mouseY>=345&&mouseY<=389) {
    stressTaskHR=countHR>0?sumHR/countHR:0;stressTaskRR=countRR>0?sumRR/countRR:0;stage=2;
    status=(stressTaskHR>stressRelaxHR||stressTaskRR>stressRelaxRR)?"Elevated during task":"No elevation detected";
  }
}
void keyPressed() {
  if(mode==1) {
    if(key=='+'||key=='=')age=min(100,age+1);
    if(key=='-')age=max(10,age-1);
  }
}
