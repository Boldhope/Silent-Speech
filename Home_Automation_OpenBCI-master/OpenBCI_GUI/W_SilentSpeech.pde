
////////////////////////////////////////////////////
//  Silent Speech Training (And Live?)
//
///////////////////////////////////////////////////,

class W_SilentSpeech extends Widget {

  //to see all core variables/methods of the Widget class, refer to Widget.pde
  //put your custom variables here...
  Button button_StartTraining;
  Meter timingMeter;
  private final int MAX_ROW = 1;
  private final int MAX_COL = 3;
  String[] trainingTargets = {"Select", "Cancel", "<Say nothing>"};
  String classificationResult = "Placeholder";
  
  int currentmillis = 0;
  int previousmillis = 0;
  int elapsedTime_ms = 0;
  
  private int countdownDuration = 10000;  // delay before rows begin to flash (ms)
  public int countdownCurrent;  // delay to allow response to settle before beginning speller acquisition
  
  private boolean trainingStarted = false;
  private boolean countdownStarted = false;
  
  private PFont bigFont;
  private final int UI_MARGIN = 3;
  private int UI_TARGETBOX_HEIGHT, UI_TARGETBOX_WIDTH;
  
  W_SilentSpeech(PApplet _parent){
    super(_parent); //calls the parent CONSTRUCTOR method of Widget (DON'T REMOVE)

    bigFont = loadFont("CourierNewPSMT-24.vlw");
    println("W_SilentSpeech - loaded font CourierNewPSMT-24.vlw");
    
    button_StartTraining = new Button(x, y - navH, 200, navH, "Start SS Training", 12);
    button_StartTraining.setFont(p4, 14);
    
    timingMeter = new Meter();
    
    // UI stuff
    UI_TARGETBOX_HEIGHT = h/10;
    UI_TARGETBOX_WIDTH = w/2 - UI_MARGIN*3;
    timingMeter.w = UI_TARGETBOX_WIDTH - 30;
    
  }

  void update(){
    super.update(); //calls the parent update() method of Widget (DON'T REMOVE)

    // put code here
    
    

  }

  void draw(){
    super.draw(); //calls the parent draw() method of Widget (DON'T REMOVE)

    // Draw UI
    // Left pane (where the training targets/words are shown)
    stroke(0f, 0f, 0f);
    fill(255f, 255f,255f);
    rect(x + UI_MARGIN , y + UI_MARGIN, w/2 - UI_MARGIN, h - UI_MARGIN);  // bounding left box
    
    // Left pane target boxes
    int xpos, ypos;
    xpos = x; ypos = y;
    for(int i = 0; i < MAX_COL; i++) {
      fill(255f, 255f,255f);
      ypos = y + (i * UI_TARGETBOX_HEIGHT) + (i * UI_MARGIN);
      rect(xpos + UI_MARGIN*2, ypos + UI_MARGIN*2, UI_TARGETBOX_WIDTH, UI_TARGETBOX_HEIGHT);
      // write word
      textSize(28);
      fill(0f, 0f, 0f);
      text(trainingTargets[i], xpos + 10, ypos + UI_MARGIN*2 + 28);
    }
    
    // Right pane (where the classification result is shown)
    stroke(0f, 0f, 0f);
    fill(255f, 255f,255f);
    rect(x + w/2 + UI_MARGIN, y + UI_MARGIN, w/2 - UI_MARGIN*2, h - UI_MARGIN);
    textSize(24);
    fill(0f, 0f, 0f);
    text("Classification Result:", x + w/2 + 10, y + UI_MARGIN + 28);
    
    // classification text box
    stroke(0f, 0f, 0f);
    fill(255f, 255f,255f);
    rect(x + w/2 + UI_MARGIN*2, y + UI_TARGETBOX_HEIGHT + UI_MARGIN*3, UI_TARGETBOX_WIDTH - UI_MARGIN, UI_TARGETBOX_HEIGHT);
    fill(0f, 0f, 0f);
    text(classificationResult, x + w/2 + 10, y + UI_MARGIN*2 + UI_TARGETBOX_HEIGHT + 28);
    
    // positioning the meter
    timingMeter.xpos = x + w/2 + UI_MARGIN*2;
    timingMeter.ypos = y + UI_TARGETBOX_HEIGHT*2 + UI_MARGIN*4;
    
    
    pushStyle();

    button_StartTraining.draw();
    timingMeter.display();

    popStyle();

  }

  void screenResized(){
    super.screenResized(); //calls the parent screenResized() method of Widget (DON'T REMOVE)

    //put your code here...
    button_StartTraining.setPos(x, y - navH);
    // UI stuff
    UI_TARGETBOX_HEIGHT = h/10;
    UI_TARGETBOX_WIDTH = w/2 - UI_MARGIN*3;
    timingMeter.w = UI_TARGETBOX_WIDTH - 30;

  }

  void mousePressed(){
    super.mousePressed(); //calls the parent mousePressed() method of Widget (DON'T REMOVE)

    //put your code here...
    if(button_StartTraining.isMouseHere()){
      button_StartTraining.setIsActive(true);
    }

  }

  void mouseReleased(){
    super.mouseReleased(); //calls the parent mouseReleased() method of Widget (DON'T REMOVE)

    //put your code here...
    if(button_StartTraining.isActive && button_StartTraining.isMouseHere()){
      toggleTraining();
    }
    button_StartTraining.setIsActive(false);

  }

  void toggleTraining() {
    if(!trainingStarted) {
      trainingStarted = true;
      button_StartTraining.setString("Stop SS Training");
      stopButtonWasPressed();
    } else {
      trainingStarted = false;
      resetTraining();
      button_StartTraining.setString("Start SS Training");
      stopButtonWasPressed();
    }
  }
  
  void resetTraining() {
    
  }

};

class Meter {
  
  float startValue, stopValue;
  float tickInterval;
  float currentValue;
  int xpos, ypos;  // pixel position
  int w, h;  // pixels
  
  // default 0 - 5 
  Meter() {
    startValue = 0.0;
    stopValue = 5.0;
    tickInterval = (stopValue - startValue)/5;
    currentValue = startValue;
    xpos = 0; ypos = 0;
    w = 200; h = 24;
  }
  
  Meter(float start, float stop) {
    startValue = start;
    stopValue = stop;
    tickInterval = (stopValue - startValue)/5;
    currentValue = startValue;
    xpos = 0; ypos = 0;
    w = 200; h = 24;
  }
  
  void setCurrentPosition(float curr) {
    currentValue = curr;
  }
  
  void display() {
    // draw meter and ticks and numbers
    stroke(0f, 0f, 0f);
    fill(255f, 255f, 255f);
    rect(xpos, ypos, w, h);
    int tickCount = (int) ((stopValue - startValue)/tickInterval);
    int tickWidth = w/tickCount;
    fill(0f, 0f, 0f);
    textSize(h);
    for(int i = 0; i <= tickCount; i++) {
      int tickStartPosX = xpos + i*tickWidth;
      int tickStartPosY = ypos + h;
      line(tickStartPosX, tickStartPosY, tickStartPosX, tickStartPosY + h);  // tick length is same as meter height
      text("" + (startValue + i*tickInterval), tickStartPosX + 3, tickStartPosY + h);
    }
    
    // draw the pos indicator
    int pAX = int (xpos + currentValue);
    int pAY = ypos + h;
    int pBX = pAX - 4;
    int pBY = pAY - h/2;
    int pCX = pAX + 4;
    int pCY = pAY - h/2;
    triangle(pAX, pAY,
             pBX, pBY,
             pCX, pCY);
    
  }
  
}