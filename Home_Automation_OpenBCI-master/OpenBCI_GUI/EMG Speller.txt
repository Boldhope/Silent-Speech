
////////////////////////////////////////////////////
//
//    W_P300Speller.pde (ie "P300 Speller")
//
//    This is a Template Widget, intended to be used as a starting point for OpenBCI Community members that want to develop their own custom widgets!
//    Good luck! If you embark on this journey, please let us know. Your contributions are valuable to everyone!
//
//    Created by: Conor Russomanno, November 2016
//
///////////////////////////////////////////////////,

class W_P300Speller extends Widget {

  //to see all core variables/methods of the Widget class, refer to Widget.pde
  //put your custom variables here...
  //Button widgetTemplateButton;
  Button button_StartSpeller;
  Button button_CollectClassification;
  private final int MAX_ROW = 1;
  private final int MAX_COLUMN = 3;
  public int runcount = 0;
  private int lastRuncount = 0;
  private int randrow = 0;
  private int randcol = 0;
  private int[] letter_pattern;
  private int targetLetterIndex = 0;
  private int targetLetterHitCount = 0;
  private int targetLetterRow = 0;
  private int targetLetterColumn = 0;
  
  int currentmillis = 0;
  int previousmillis = 0;
  int elapsedTime_ms = 0;
  private int maxRunCount = 60;  // temp magic number
  
  private int stimuliDelay = 2000; // millisecond delay between switching row and columns
  private String fileString = "C:\\Users\\the0r\\Documents\\School\\CSUF\\EGCP598 BCI LAB\\Home_Automation_OpenBCI\\OpenBCI_GUI\\SavedData\\P300SpellerStimuliRecord.txt";
  private int[] hit_count;
  private int delayTime = 5;
  private final int NUM_LETTERS = 3;
  private final int NUM_TRIALS = 3;
  private int maxHitCount = NUM_LETTERS*NUM_TRIALS;  // temp magic number, it is the number of trials we do.
  private final int NUM_WORDS = 3;
  public boolean WordTrigger = false;
  public int Word_index = 0;
  String[] Wordbank = {"Confirm", "Deny", "Do Nothing"};
  private final int option = 2;
  private int letter_runs = 0;
  private boolean spellerStarted = false;
  private boolean countdownStarted = false;
  private boolean dice_roll_success = false;
  
  private boolean LightStarted = false;
  private boolean LightOn = false;
  private boolean TimePassed = false;
  private final int blinkDelay = 3000;
  
  private boolean pause = true;
  private int totalruns = 0;
  public int lastRun = 0;
  private char previous_character = 'F';
  private int countdownDuration = 10000;  // delay before rows begin to flash (ms)
  public int countdownCurrent;  // delay to allow response to settle before beginning speller acquisition
  char[] characters = {'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'};
  private String fs = System.getProperty("file.separator");
  private PFont bigFont;
  private int target_character_index = 0;
  private int target_index_variable = 0;
  private int class_runs = 0;
  public final int MAX_RUNS = 1;
  public boolean classification = false; //Classify the signal
  public int[] target_indices;
  W_P300Speller(PApplet _parent){
    super(_parent); //calls the parent CONSTRUCTOR method of Widget (DON'T REMOVE)

    //This is the protocol for setting up dropdowns.
    //Note that these 3 dropdowns correspond to the 3 global functions below
    //You just need to make sure the "id" (the 1st String) has the same name as the corresponding function
    //addDropdown("Dropdown1", "Drop 1", Arrays.asList("A", "B"), 0);
    //addDropdown("Dropdown2", "Drop 2", Arrays.asList("C", "D", "E"), 1);
    //addDropdown("Dropdown3", "Drop 3", Arrays.asList("F", "G", "H", "I"), 3);

    /*
    widgetTemplateButton = new Button (x + w/2, y + h/2, 200, navHeight, "Design Your Own Widget!", 12);
    widgetTemplateButton.setFont(p4, 14);
    widgetTemplateButton.setURL("http://docs.openbci.com/Tutorials/15-Custom_Widgets");
    */
    bigFont = loadFont("CourierNewPSMT-24.vlw");
    println("W_P300_Speller - loaded font CourierNewPSMT-24.vlw");
    
    button_StartSpeller = new Button(x, y - navH, 200, navH, "Start Recording", 12);
    button_StartSpeller.setFont(p4, 14);
    button_CollectClassification = new Button(x+200, y-navH, 200, navH, "Collect Data", 12);
    button_StartSpeller.setFont(p4, 14);
    countdownCurrent = countdownDuration/1000;
    hit_count = new int[5];
    letter_pattern = new int[25];
    //target_indices = new int[5]; //Reset this after
    
  }

  void update() {
    super.update(); //calls the parent update() method of Widget (DON'T REMOVE)

    //put your code here...

  }

  void draw(){
    super.draw(); //calls the parent draw() method of Widget (DON'T REMOVE)

    //put your code here... //remember to refer to x,y,w,h which are the positioning variables of the Widget class
    pushStyle();

    //widgetTemplateButton.draw();
    // START -- Drawing character boxes
    //ROW (x axis) in this case are the columns of previous code
    //COLUMN (y axis) in this case are the rows of previous code
    if (spellerStarted && targetLetterHitCount < maxHitCount) { //In the case this is not first runtime, get random ints.
      //System.out.printf("Current ms: %d, previous ms: %d, elapsed time ms: %d \n", currentmillis, previousmillis, elapsedTime_ms);
      // if elapsed time since last row and column change > stimuli delay, generate a new pair of row and col
      // otherwise, keep drawing the previous row/col
       if (runcount != lastRun) { //&& end != true, add down in classification conditions?
       switch(option) {
        case 1: 
          countdownCurrent = 5;
          lastRun = runcount;
          break;
        case 2:
          countdownCurrent = delayTime;
          lastRun = runcount;
        pause = true;
        break;
        default:
        break;
        }
       }
      if(countdownCurrent == 0) {  // after countdown has reached 0
        countZero(); //Do countZero function, which allocates the letters in order
      } else {
        if(elapsedTime_ms > 1000) {  // every second during countdown before starting speller
          elapsedTime_ms = 0;
          countdownCurrent--;
        }
      }
    } 
    if(classification) {
      DrawLetters();
      //println("Entering Classification");
    } else if (LightStarted) {
      DrawLight();
    }
    // END -- Drawing character boxes 
    //delay(stimuliDelay);
    CountDown();
    DrawButtons();

  }
  void DrawButtons() {
    button_StartSpeller.draw();
    button_CollectClassification.draw();
    popStyle();
  }
  void DrawLight() { //Draws a blinking light to signify whether or not data collection is active
    DrawWordList(); //Draws the list of words that are possible
    if((!LightOn && TimePassed) || (LightOn && !TimePassed)) { //Turn the light on. Condition 1 is if first pass through. Condition 2 is redrawing to make sure the color stays.
      fill(0f,0f,255f);
      stroke(255f);
      rect(x, y+(h/NUM_WORDS), 100, 100);
      textSize(16);
      fill(255f,255f,255f);
      text("RC", x+(w/MAX_COLUMN), y+(h/NUM_WORDS)+50);
      TimePassed = false; //Reset the fact that the stimuli delay has passed.
      LightOn = true;
      WordTrigger = false; //Reset WordTrigger here so that there is some delay before the word highlighted is gone.
      //println("Turning Light on");
 
    } else if ((TimePassed && LightOn) || (!LightOn && !TimePassed)) { //Reset the light to its off state.
       if((TimePassed && LightOn)) {
         lastRun++;
         current_rand_index = 0; //Set to an arbitrary index.
         println("Turning Light off");
       }
       TimePassed = false;
       LightOn = false;
       fill(0f,0f,0f);
       stroke(255f);
       rect(x, y+(h/NUM_WORDS), 100, 100);
       textSize(16);
       fill(255f,255f,255f);
       text("Not RC", x, y+(h/NUM_WORDS)+50);
    }
    //CheckLightState();
    
    
  }
  void DrawWordList() {
  
  for(int i = 0; i < NUM_WORDS; i++) {
    if(WordTrigger && i == Word_index) {
      fill(0f,0f,255f);
    } else {
      fill(105f,105f,105f);
    }
    stroke(255f);
    rect(x+2*(w/MAX_COLUMN), y+(h/NUM_WORDS)*i, (w/MAX_COLUMN), (h/NUM_WORDS)); //Put the words at the beginning of the third column, from top to bottom row.
    textSize(16);
    fill(0f, 0f, 0f);
    text(Wordbank[i], x+2*(w/MAX_COLUMN)+((w/MAX_COLUMN)/2), y+(h/NUM_WORDS)*(i+1)-((h/NUM_WORDS)/2));
  }
  }
  void CountDown() {
    elapsedTime_ms += (currentmillis - previousmillis);
    previousmillis = currentmillis;
    currentmillis = millis();
  int Delay = 0;
  if(!LightOn) {
    Delay = stimuliDelay + blinkDelay;
  } else {
    Delay = stimuliDelay;
  }
    if(elapsedTime_ms > Delay && LightStarted) {
      TimePassed = true;
      elapsedTime_ms = 0;
      println("Setting TimePassed to True");
    }
    //draw countdown if active
    if(countdownCurrent > 0) {
      textFont(bigFont);
      fill(255f, 255f, 255f); //text color white
      text(countdownCurrent,w/2,h/2);
    }
  }
  void DrawLetters() { //One by one, highlight MAX_COLUMN # of letters to blue.
    //println("In DrawLetters");
  float charXOffset, charYOffset;
    charXOffset = (w/MAX_COLUMN) / 2;
    charYOffset = (h/MAX_ROW) / 2;
    for (int i = 0; i < MAX_ROW; i++) { //y value
      float ypos = y + (h/MAX_ROW)*i;
      for (int j = 0; j < MAX_COLUMN; j++) { //x value
        float xpos = x + (w/MAX_COLUMN)*j;
        if (runcount == 0 || !spellerStarted){ //If first runtime, this is a special case. Display all characters
        
          fill(0f);
          if(j+(i*(MAX_ROW)) == targetLetterIndex) {  // color the target letter blue
            fill(0f, 0f, 255f);
          }
          stroke(255f);
          rect(xpos, ypos, (w/MAX_COLUMN), (h/MAX_ROW));
          textSize(32);
          fill(255f, 255f, 255f);
          text(characters[(j+(i*(MAX_COLUMN)))], xpos + charXOffset, ypos + charYOffset);
        } else if (((runcount > 0) || (totalruns != 0)) && targetLetterHitCount < maxHitCount) { //If any other run time between 0 and max runcount
          if(randrow == i || randcol == j) {  
            // if current rectangle's row is the randomly selected row, or if the column is the selected column
            fill(105f);  // set rect fill color to grey(lit)
          } else {
            fill(0f);  // otherwise set the fill color to black
          }
          
          if(randrow == i && randcol == j) {  
            fill(105f, 105f, 105f);  // grey if not the target letter
            if (j+(i*(MAX_COLUMN)) == targetLetterIndex) {
              fill(0f, 0f, 255f);  // blue if target letter
              
              // increment only if stimuli has changed
              if(runcount != lastRuncount) {
                targetLetterHitCount++; // increment times target letter has been highlighted in the intersection
                System.out.printf("Target Letter Hit Count: %d. Index: %d - Char: %c - Row: %d - Col: %d \n", targetLetterHitCount, j+(i*MAX_ROW), characters[(j+(i*MAX_COLUMN))], i, j);
                lastRuncount = runcount;
                if(targetLetterHitCount == maxHitCount) { //Reset the speller to its original state if
                  for (int p = 0; p < 25; p++) {
                    println("Letter #" + p + ": " + letter_pattern[p]);
                  }
                  if (classification && (class_runs < MAX_RUNS)) {
                    class_runs++;
                    resetSpeller();
                  } else if(!classification) { //If we are not classifying or classification runs has not reached the maximum amount we want to do, then we will continue to utilize the speller.
                    resetSpeller();
                  } else {
                    classification = false;
                    resetSpeller(); //Wait for 10 second delay to finish.
                  }
                  totalruns++;
                }
              }
            }
          }

          stroke(255f);  // rectangle border color
          rect(xpos, ypos, (w/MAX_COLUMN), (h/MAX_ROW));  // draw rectangle
          textSize(32);  // set text size
          fill(255f, 255f, 255f);  // text color white
          text(characters[(j+(i*(MAX_COLUMN)))], xpos + charXOffset, ypos + charYOffset);  // writes the character 
          //System.out.printf("Index: %d - Char: %c - Row: %d - Col: %d \n", j+(i*MAX_ROW), characters[(j+(i*MAX_COLUMN))], i, j);
        } else {
          toggleSpeller();
        }
      }  // end column loop
    }  // end row loop
  }
  void countZero() {
      //println("In CountZero");
      if(class_runs >= MAX_RUNS) { //End delay (delayed so that the program can save)
      targetLetterHitCount = maxHitCount;
      toggleSpeller();
    }
  
    if(elapsedTime_ms > stimuliDelay) {
      elapsedTime_ms = 0;
      //randomizeTargetLetter();
        if((letter_runs != 0)) {
          ChangeLetter();
        }
        randrow = targetLetterRow;
        randcol = targetLetterColumn;
        current_rand_index = (randcol + randrow*MAX_COLUMN);
        
        if(letter_runs > 0) { //Do not increment for the first run.
          runcount++;
        }
        letter_runs++;
        println("randcol is now " + randcol);
     }
  }
  
  void resetSpeller() {
    println("Reset");
    for(int i = 0; i < 5; i++) { //Reset hit_count array keeping track of all letters.
      hit_count[i] = 0;
    }
    runcount = 0;
    lastRuncount = 0;
    countdownCurrent = countdownDuration/1000;
    targetLetterHitCount = 0;
    //randomizeTargetLetter(); //No need to randomize early.
    elapsedTime_ms = 0;
  }
  void ChangeLetter() {
    switch(targetLetterColumn) {
    case 0:
    targetLetterColumn = 1;
    break;
    case 1:
    targetLetterColumn = 2;
    break;
    case 2:
    targetLetterColumn = 0;
    break;
    //case 3:
    //targetLetterColumn = 4;
    //break;
    //case 4:
    //targetLetterColumn = 0;
    //break;
    default:
    break;
    }
    targetLetterIndex = targetLetterColumn;
  }
  void randomizeTargetLetter() {
    targetLetterRow = int(random(MAX_ROW));
  
    boolean good_run = false;
    do {
    float[] dice_roll = new float[5];
    for(int p = 0; p < 5; p++) {
      if (hit_count[p] < 5) {
        dice_roll[p] = random(0, 100);
      } else {
        dice_roll[p] = 0;
      }
    }
     int max_letter_index = 0;
     float max_roll = 0;
     for(int letter_position = 0; letter_position < NUM_LETTERS; letter_position++) {
       if (dice_roll[letter_position] > max_roll) {
         max_roll = dice_roll[letter_position];
         max_letter_index = letter_position;
       }
     }
    if(previous_character != characters[max_letter_index]) {
      targetLetterColumn = randcol = max_letter_index;
      hit_count[max_letter_index]++;
      previous_character = characters[max_letter_index];
      good_run = true;
    } else if (previous_character == characters[max_letter_index] && runcount >= 23) { 
      //Special case
      targetLetterColumn = randcol = max_letter_index;
      hit_count[max_letter_index]++;
      previous_character = characters[max_letter_index];
      good_run = true;
    }else {
      good_run = false; //RUN AGAIN.
    }
    }while(good_run != true);
    current_rand_index = (randcol + randrow*MAX_COLUMN);
    println("RUN # : " + runcount);
    println("NOW ON INDEX " + current_rand_index);
    letter_pattern[runcount] = current_rand_index;
    //runcount++;
    dice_roll_success = false;
    targetLetterIndex = randcol;

    //targetLetterIndex = targetLetterColumn+(targetLetterRow*MAX_COLUMN);
  
  }

  void screenResized(){
    super.screenResized(); //calls the parent screenResized() method of Widget (DON'T REMOVE)

    //put your code here...
    //widgetTemplateButton.setPos(x + w/2 - widgetTemplateButton.but_dx/2, y + h/2 - widgetTemplateButton.but_dy/2);
    button_StartSpeller.setPos(x, y - navH);


  }

  void mousePressed(){
    super.mousePressed(); //calls the parent mousePressed() method of Widget (DON'T REMOVE)

    //put your code here...
    /*
    if(widgetTemplateButton.isMouseHere()){
      widgetTemplateButton.setIsActive(true);
    }
    */
    if(button_StartSpeller.isMouseHere()) {
      toggleSpeller();
    }
    if(button_CollectClassification.isMouseHere()) {
      toggleClassification();
      
    }
  }
  void toggleClassification() {
    if(!classification) {
      classification = true;
      spellerStarted = true;
      button_CollectClassification.setString("Stop Collection");
      stopButtonWasPressed();
    } else {
      classification = false;
      spellerStarted = false;
      resetSpeller();
      button_CollectClassification.setString("Start Collection");
      stopButtonWasPressed();
      Erase();
    }
  }
  void toggleSpeller() {
    if(!LightStarted) {
      LightStarted = true;
      button_StartSpeller.setString("Stop Flickering");
      stopButtonWasPressed();
    } else {
      LightStarted = false;
      //resetSpeller();
      button_StartSpeller.setString("Start Flickering");
      stopButtonWasPressed();
    }
  }
  void Erase() {
    fill(255f,255f,255f);
    rect(x+(w/MAX_COLUMN), y, w, h);
  }
  boolean isSpellerStarted() {
    return spellerStarted;
  }
  
  int getTargetLetterIndex() {
    return targetLetterIndex;
  }
  
  int getTargetLetterRow() {
    return targetLetterRow;
  }
  
  int getTargetLetterColumn() {
    return targetLetterColumn;
  }
  
  String getStimuliFileName() {
    return fileString;
  }

  void mouseReleased(){
    super.mouseReleased(); //calls the parent mouseReleased() method of Widget (DON'T REMOVE)

    //put your code here...
    /*
    if(widgetTemplateButton.isActive && widgetTemplateButton.isMouseHere()){
      widgetTemplateButton.goToURL();
    }
    widgetTemplateButton.setIsActive(false);
    */

  }
/*
  //add custom functions here
  void dumpStimuliRecord(){
    // dump stimuli record to file
    if(runcount > 0) {
      try {
        BufferedWriter bwr = new BufferedWriter(new FileWriter(new File(fileString)));
        bwr.append(stimuliRecord);
        bwr.flush();
        bwr.close();
      } catch(IOException e) {
        e.printStackTrace();
      }
    }
  }
*/

};

/*
//These functions need to be global! These functions are activated when an item from the corresponding dropdown is selected
void Dropdown1(int n){
  println("Item " + (n+1) + " selected from Dropdown 1");
  if(n==0){
    //do this
  } else if(n==1){
    //do this instead
  }

  closeAllDropdowns(); // do this at the end of all widget-activated functions to ensure proper widget interactivity ... we want to make sure a click makes the menu close
}

void Dropdown2(int n){
  println("Item " + (n+1) + " selected from Dropdown 2");
  closeAllDropdowns();
}

void Dropdown3(int n){
  println("Item " + (n+1) + " selected from Dropdown 3");
  closeAllDropdowns();
}
*/