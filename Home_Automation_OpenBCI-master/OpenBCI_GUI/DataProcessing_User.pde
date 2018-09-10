import java.nio.file.*;
import java.io.*;
import static java.nio.file.StandardOpenOption.*;
import processing.net.*;
//------------------------------------------------------------------------
//                       Global Variables & Instances
//------------------------------------------------------------------------
/*TO-DO LIST (IN THIS ORDER):
  -FIGURE OUT THE TIMING ISSUE ON THE FIRST LETTER
  -FIT LED FEATURE INTO SPELLER
  -MAKE THE SPELLER STILL VISIBLE, AS A MEANS OF SHOWING WHAT WE HAVE DETECTED WHEN THE ONE WE WANT FLASHES
  */
DataProcessing_User dataProcessing_user;
Client myClient;
boolean drawEMG = false; //if true... toggles on EEG_Processing_User.draw and toggles off the headplot in Gui_Manager
boolean drawAccel = false;
boolean drawPulse = false;
boolean drawFFT = true;
boolean drawBionics = false;
boolean drawHead = true;
boolean Col_compl = false;

String oldCommand = "";
boolean hasGestured = false;
int previous_letter_index; //Keeps track of the previous letter so that we can save data into the right array element.  
final String filename = "TargetData.txt";
final String filename2 = "Background.txt";
final boolean appendData = true;
final int SAMPLE_SIZER = 500; //Sample Size of the filtered data from board for two seconds.
final int NUM_CHANNELS_USED = 2;
final int NUM_LETTERS_USED = 3;
final int baseline = 2; //Data from the intentionally "noisy" letter
final int delay_time = 1000;
final int NUM_SETS = 10;
final int NO_SET = 10000;
//float[] baseline_avg = new float[NUM_CHANNELS_USED];
boolean[] Setindicator = new boolean[NUM_SETS]; //Indicates which sets are valid. Setindicator[0] will be set 0, and so on.
int index;
float [] sum = new float[NUM_CHANNELS_USED];
float [][][] Time_Data = new float[SAMPLE_SIZER][NUM_CHANNELS_USED][NUM_LETTERS_USED]; //Hardcoded. From left to right, the first dimension represents 125 samples (the last two seconds of run time). The second element represents the 4 channels we use. The third dimension represents the 5 different letters.
int Cnum_runs = 0;
//float [][][] Time_Data = new float[125][8][5];
//------------------------------------------------------------------------
//                            Classes
//------------------------------------------------------------------------
//KNN classifier (stores the testing data).
class KNNinfo {
   float Time;
   float Peak;
   boolean target_or_not;
 }
 class MinimumIndices {
   int MinIndex;
   float MinDistance;
   boolean target;
 }
class DetectedPeak { 
  int bin;
  float freq_Hz;
  float rms_uV_perBin;
  float background_rms_uV_perBin;
  float SNR_dB;
  boolean isDetected;
  float threshold_dB;
 
  DetectedPeak() {
    clear();
  }

  void clear() {
    bin=0;
    freq_Hz = 0.0f;
    rms_uV_perBin = 0.0f;
    background_rms_uV_perBin = 0.0f;
    SNR_dB = -100.0f;
    isDetected = false;
    threshold_dB = 0.0f;
  }

  void copyTo(DetectedPeak target) {
    target.bin = bin;
    target.freq_Hz = freq_Hz;
    target.rms_uV_perBin = rms_uV_perBin;
    target.background_rms_uV_perBin = background_rms_uV_perBin;
    target.SNR_dB = SNR_dB;
    target.isDetected = isDetected;
    target.threshold_dB = threshold_dB;
  }
}

class DataProcessing_User {
  private float fs_Hz;  //sample rate
  private int n_chan; //Same as nchan in EEG_Processing, except it is named n_chan.
  private int SetLength = 0;
  DetectedPeak[] detectedPeak;
  DetectedPeak[] peakPerBand;
  int cd; //Takes a look at whether or not cd is equal
  final int TOTAL_TRIALS = 25; //# flashes per letter * total amount of letters.
  //final int NUM_CHANNELS_USED = 1;
  final int NUM_OF_TRIALS = 3; //NUMBER OF TRIALS FOR TARGET DETECTION
  //final int NUM_LETTERS_USED = 3; 
  final int N = 10; //Maximum number of points we use to check (for extra accuracy).
  final int max_wait_runs = 5; //The amount of one second intervals that should be waited for.
  final int maxruns_persecond = 24;
  public final int option = 2; //Set to the option you want. If set to 1, it will do frequency-domain analysis. If set to 2, it will do time-domain analysis (save data). If 3, it will read in the data and classify in time-domain.
  final int SAMPLE_SIZE = 48; //24 samples per second, so change by the amount of seconds that you let the stimulus remain.
  final int MAX_DATA_SIZE = SAMPLE_SIZER*(NUM_LETTERS_USED-1); //KEEP IN MIND THE FACT THAT IT ONLY KEEPS IN MIND THAT THIS KEEPS THE LAST LETTER AS A MEANS OF DOING NOTHING, THOUGH IF WE WANTED TO TAKE DATA FOR THE LAST LETTER IT WOULD BE SAMPLE_SIZE*(NUM_LETTERS_USED)
  //final int MAX_DATA_SIZE = SAMPLE_SIZE*(NUM_LETTERS_USED-1);
  final float R = .9; //Relational ratio for the hit count values. It would be best if this value was kept around the range of .8 to .9, though other ratios can be tested.
  /*VARIABLES THAT KEEP TRACK OF TIMING*/
  int currentmillis = 0;
  int previousmillis = 0;
  int[] peakCount = new int[NUM_CHANNELS_USED];
  int runs = 0;
  boolean wait = false; //If true, then it will not collect data. If false, then it will collect data.
  boolean datafilled = false;
  int wait_runs = 0;
  /*VARIABLES THAT HOLD DATA FOR EACH CHANNEL*/
  float[][][] rms1 = new float[SAMPLE_SIZE][NUM_CHANNELS_USED][NUM_LETTERS_USED]; //24 samples since this part of the program is only called 240 times in 10 seconds, which is 24 times per second.
  float[][] rms = new float[SAMPLE_SIZE][NUM_CHANNELS_USED]; 
  float[][][] background_rms = new float[SAMPLE_SIZE][NUM_CHANNELS_USED][NUM_LETTERS_USED]; //4 is the number of channels used.
  float[][][] std_uV = new float[SAMPLE_SIZE][NUM_CHANNELS_USED][NUM_LETTERS_USED]; //[Max_samples][# max channels][max num of letters]
  final int WINDOW_SIZE = 5;
  private float[] averages = new float[NUM_CHANNELS_USED];
  private float[] stdDev = new float[NUM_CHANNELS_USED];
  private float[][] rmsBuffer = new float[NUM_CHANNELS_USED][SAMPLE_SIZER*WINDOW_SIZE];
  private int TOTAL_SAMPLES = 0;
  private int dev_run = 0;
  int sample_position = 0;
  int prev_trial_count = 0; //Keep track of the previous trial.
  int trial_count = 0; //Count the number of trials we have stored.
  int currentruncount = 0;
  int num_skips = 0;
  int num_completions = 0;
  int num_runs = 0;
  float time_frame = 2f; //Change if you change the amount of time a stimulus stays.
  //float distance;
  float[][] Stored_Data = new float[NUM_CHANNELS_USED][MAX_DATA_SIZE];
  boolean[][] TargetOrNot = new boolean[NUM_CHANNELS_USED][MAX_DATA_SIZE];
  final int IgnoreChan = 8;
  private boolean Load_data = false;
  private boolean continuous_peak = false;
  //float[] max_hit = new float[NUM_LETTERS_USED]; //Commented out, don't remember if it did something
  int letter_target_index = 0; //ONLY USED WHEN CLASSIFYING. ASSUMES INDEX 0-4 IN THAT ORDER TO CLASSIFY.
  //int[] sample_positions_ofletters;
  /*******************************************/
  boolean switchesActive = false;
  boolean file_active = false;
  boolean first_run = true;
  //Keep track of the time
  int sample_count = 0; //An amount we will divide by 10 in order to get the average sample_count.
  //Keep track of the previous_rand_index
  int previous_rand_index = 0; //LOOK AT THIS.
  float[] average = new float[NUM_CHANNELS_USED];
  //SET THE MAX DEVICES (amount of smart devices you have).
  final int MAX_DEVICES = 3;
  //final int time_per_target = 500; //Set the time spent at each target character to be equal to 500 ms. May need to be set differently depending on the time per character flash
  final float detection_thresh_dB = 5.5f;
  final float min_allowed_peak_freq_Hz = 7.9f;
  final float max_allowed_peak_freq_Hz = 14.1f;
  final float[] processing_band_low_Hz = {8.0};
  final float[] processing_band_high_Hz = {15.0};
  final float[] thresh = {15.0, 15.0, 10.0, 10.0};
  private int[] data_index = new int[NUM_CHANNELS_USED]; //Make indices for each channel to store data.
  //DEVICE NAMES BELOW, MODIFY TO SUIT THE NAMES WE WANT
  /*The first array element will be active during the first character, the second array element
  element will be active during the second character, and so on.*/
  //In the string array below, devices will correspond to the characters in the array from A to Z, with A representing the first element
  final String[] Devices = new String[]{"A", "B", "C", "Door", "E"};
  MinimumIndices[] CompData = new MinimumIndices[N];
  Button leftConfig = new Button(3*(width/4) - 65,height/4 - 120,20,20,"\\/",fontInfo.buttonLabel_size);
  Button midConfig = new Button(3*(width/4) + 63,height/4 - 120,20,20,"\\/",fontInfo.buttonLabel_size);
  Button rightConfig = new Button(3*(width/4) + 190,height/4 - 120,20,20,"\\/",fontInfo.buttonLabel_size);
  
  
  
  //class constructor
  DataProcessing_User(int NCHAN, float sample_rate_Hz) {
    n_chan = NCHAN;
    fs_Hz = sample_rate_Hz;
    
    detectedPeak = new DetectedPeak[n_chan];
    for (int Ichan=0; Ichan<n_chan; Ichan++) detectedPeak[Ichan]=new DetectedPeak();

    int nBands = processing_band_low_Hz.length;
    
    peakPerBand = new DetectedPeak[nBands];
    for (int Iband=0; Iband<nBands; Iband++) peakPerBand[Iband] = new DetectedPeak();
    String Temp;
    for (int d=0; d<MAX_DEVICES; d++) {
       Device[d] = new TextToSpeak(); //Initialize each Device's TTS
       Initialize(Device[d], Devices[d]);
    }
    
  }

  //add some functions here...if you'd like

  //here is the processing routine called by the OpenBCI main program...update this with whatever you'd like to do. Many conditions are checked here.
  public void process(float[][] data_newest_uV, //holds raw bio data that is new since the last call
    float[][] data_long_uV, //holds a longer piece of buffered EEG data, of same length as will be plotted on the screen
    float[][] data_forDisplay_uV, //this data has been filtered and is ready for plotting on the screen
    FFT[] fftData) {              //holds the FFT (frequency spectrum) of the latest data

    //for example, you could loop over each EEG channel to do some sort of time-domain processing
    //using the sample values that have already been filtered, as will be plotted on the display
    float EEG_value_uV;
    currentmillis = millis();
    if(((currentmillis-previousmillis)/1000) >= 1) { //If a second has passed, enter.
      previousmillis=currentmillis;
      if(wait == true) { //If wait is true from detection, increment until we can begin again.
        wait_runs++;
        //println("Waiting...");
        if (wait_runs == max_wait_runs) { //Check if safe to run again.
          wait = false; //It is now safe to run again.
          wait_runs = 0;
        }
      }
      //println("Reset runs...");
    }
    if(w_p300speller.countdownCurrent == 0 && wait == false) { //If countdownCurrent is equal to 0, then we will begin data collection. It will only take samples as long as the number of runs per second is equal to 24.

        if (sample_position < SAMPLE_SIZE) {
          processMultiChannel(data_newest_uV, data_long_uV, data_forDisplay_uV, fftData);
          if(sample_position == SAMPLE_SIZE) { //Check to see if it is somewhat filled before allowing it to complete.
          datafilled = true;
          //println("Finished datacollection");  
        }
        //println("Finished datacollection");  
      } 
    }
    if(((w_p300speller.lastRun)) != trial_count) {
          //trial_count = w_p300speller.runcount;
          println("Speller lastRun: " + w_p300speller.lastRun);
          println("Trial count is: " + trial_count);
          trial_count = w_p300speller.lastRun;
          //println("TRIALCOUNT IN DATAPROCESSING_USER IS NOW : " + trial_count);
          //println("Skipping some data...");
          previous_letter_index = previous_rand_index; //Set the previous_letter_index to the previous_rand_index so that we can read data which has already passed.
          previous_rand_index = current_rand_index; //Set the previous index to the current index.
          //sample_positions_ofletters[trial_count] = sample_position;
          num_skips++;
          sample_position = 0;
          num_runs++;
          println("Trial Count is now: " + trial_count);
          println("Run Count is now: " + w_p300speller.runcount);
          //stopButtonWasPressed();
          println("w_p300speller.runcount is " + w_p300speller.runcount + ", trial count is " + trial_count);
          thread("Collect");
         
          println("Delay the system so that data can be collected correctly");
          Load_data = true;
        } 
       switch (option) {
            case 1: 
              if(trial_count == NUM_LETTERS_USED*NUM_OF_TRIALS-1 && (w_p300speller.runcount != trial_count)) { //compensate for the lack of data and check anyways. //Lower trial count.
                  FixData();
                  println("Saving Data");
                  println("Saving Data while running");
                  //Average data in this function and store in an array
                  //Here for classification, we assume the user focuses on A, then B, then C, then D, then E. If this doesn't work, we can select some arbitrary letter for non-target and try with amplitudes around the same timeframe.
                  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
        
                    //for(int sample_position = 0; sample_position < SAMPLE_SIZE; sample_position++) { //Just in case we need it for better classification.
                    //  //Store the training data for select (the first word)
                    //  Stored_Data[iChan][data_index[iChan]] = ((rms1[sample_position][iChan][0])/NUM_OF_TRIALS); //Data for A stored first
                    //  TargetOrNot[iChan][data_index[iChan]++] = false; //Define false to be the no command
                    //}
                    //for(int sample_position = 0; sample_position < SAMPLE_SIZE; sample_position++) {
                    //  println("data index is " + data_index[iChan]);
                    //  //Store the training data for cancel (the first word
                    //  Stored_Data[iChan][data_index[iChan]] = ((rms1[sample_position][iChan][1])/NUM_OF_TRIALS); //Data for B stored next.
                    //  TargetOrNot[iChan][data_index[iChan]++] = true; //Let us define true to be the yes command
                    //}
                    for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
                      Stored_Data[iChan][data_index[iChan]] = (Time_Data[sample_position][iChan][0]);
                      //Stored_Data[iChan][data_index[iChan]] = (Time_Data[sample_position][iChan][0]);
                      TargetOrNot[iChan][data_index[iChan]++] = false;
                    } 
                    for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
                      Stored_Data[iChan][data_index[iChan]] = (Time_Data[sample_position][iChan][1]);
                      //Stored_Data[iChan][data_index[iChan]] = (Time_Data[sample_position][iChan][1]);
                      TargetOrNot[iChan][data_index[iChan]++] = true;
                    }
                    average[iChan] = sum[iChan]/NUM_OF_TRIALS;
                //saveData1();
                //trial_count = 0;
                //println("In save data");
                // 96 samples for each channel. 96 samples * 2 channels. 48 samples in total for each channel at a time = 192 samples * 5 trials = 960 samples. So that means the first 48 samples of each deal with letter A, the next 40 deal with B, and so on.
                
                }
                println("prepare to save data...");
                 saveData1();
                 trial_count = 0;
                }
             break;
           case 2:  //LOAD TEST DATA FOR TESTING OUR RECENTLY COLLECTED DATA CHANGE THIS FUNCTION TO CLASSIFY YES OR NO
             //while(Col_compl != true) {
             //} //Loop until it is true.
             if((Col_compl == true)) { //&& (datafilled == true)
               loadTestData1();
               //println("Completed loadTestData");
               Load_data = false;
               Col_compl = false;
             }
             break;
           case 3:
             if(datafilled) {
               datafilled = false;
               //CheckRMS();
             }
             break;
           case 4:
             if(datafilled) { //If it doesn't work as intended, use Load_data to see if it changes timing.
               datafilled = false;
               //checkRateRMS();
             }
             break;
           case 5:
             if(Col_compl) {
               //datafilled = false;
               Col_compl = false;
               CheckStdDev();
             }
             break;
           default:
             println("The max value num_runs goes to is: " + num_runs);
               
          }
    //  //println("Checking condition trial_count");
     
    }
float[] FindFullDev(float[] Average) {
  float[] StdDev = new float[NUM_CHANNELS_USED];
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    float temp = 0;
    for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
      temp += pow((Time_Data[sample_position][iChan][previous_letter_index] - Average[iChan]), 2);
    }
    StdDev[iChan] = sqrt(temp/(SAMPLE_SIZER-1));
  }
  return StdDev;
}
float[] FindSumandAverage() {
  float[] Average = new float[NUM_CHANNELS_USED];
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    float temp = 0;
    for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
      temp += Time_Data[sample_position][iChan][previous_letter_index];
    }
    Average[iChan] = (temp/SAMPLE_SIZER);
  }
  return Average;
}
void FixData() { //Fix the Data by averaging then normalizing.
for(int letter_index = 0; letter_index < NUM_LETTERS_USED-1; letter_index++) { //Average and normalize the data acquired.
    for(int Chan = 0; Chan < NUM_CHANNELS_USED; Chan++) {  
      ComputeAverage(Chan, letter_index);
    }
    SmoothData(letter_index);
    NormalizeData(letter_index);
    //SmoothData(letter_index);
  }
}
//Make into one function, with various options? For all the functions that are related
void ComputeAverage(int iChan, int letter_index) { //Average out the Time_Data array.
  for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
    Time_Data[sample_position][iChan][letter_index] = (Time_Data[sample_position][iChan][letter_index]/(NUM_OF_TRIALS));
  }
}
float AverageDev(float[] StdDev) {
  float temp = 0;
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    temp+=StdDev[iChan];
  }
  temp = (temp/NUM_CHANNELS_USED);
  return temp;
}
void SmoothData(int letter_index) { //Parameter to include: letter_index
  final int window_size = 5;
  final int NUM_OF_ITERATIONS = 5;
  for(int iteration = 0; iteration < NUM_OF_ITERATIONS; iteration++) {
    float[][] TempArray = new float[NUM_CHANNELS_USED][SAMPLE_SIZER];
    for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
      for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
        float TempSum = 0;
        if(sample_position > window_size && (sample_position < SAMPLE_SIZER-window_size)) {
          for(int i = sample_position; i < (window_size+sample_position); i++) {
            TempSum += Time_Data[i][iChan][letter_index];
          }
          TempArray[iChan][sample_position] = (TempSum/window_size);
        } else if(sample_position >= SAMPLE_SIZER-window_size) {
          TempArray[iChan][sample_position] = Time_Data[sample_position][iChan][letter_index];
        }
        else {
          TempArray[iChan][sample_position] = Time_Data[sample_position][iChan][letter_index];
        }
      }
      
    }
    //Reinitialize Time_Data with values of TempArray
    Reinitialize(letter_index, TempArray);
  }
}
void Reinitialize(int letter_index, float[][] TempArray) {
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
    Time_Data[sample_position][iChan][letter_index] = TempArray[iChan][sample_position];
    }
  }
}
void NormalizeData(int letter_index) {
     float[] max_val = new float[NUM_CHANNELS_USED];
     max_val = findMaxPeak(letter_index);
     for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
       for(int i = 0; i < SAMPLE_SIZER; i++) {
         Time_Data[i][iChan][letter_index] = (Time_Data[i][iChan][letter_index]/max_val[iChan]);
       }
     }
   }
   
float[] findMaxPeak(int letter_index) {
 float[] max = new float[NUM_CHANNELS_USED];
 for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
   for(int i = 0; i < SAMPLE_SIZER; i++) {
     if(abs(Time_Data[i][iChan][letter_index]) > max[iChan]) {
       max[iChan] = abs(Time_Data[i][iChan][letter_index]);
     }
   }
   
 }
 return max;
 }
//**********************************************
//Loop through, calculate, and get data saved.
//**********************************************
  public void processMultiChannel(float[][] data_newest_uV, float[][]data_long_uV, float[][] data_forDisplay_uV, FFT[] fftData) {
    boolean isDetected = false;
    if (sample_position < SAMPLE_SIZE && previous_rand_index < MAX_DEVICES) { //As long as previous_rand_index is equal to its initial value of 100 (or larger than MAX_DEVICES), it will not begin reading data (option 1), in this case, we have detection checks only when the index is less than MAX_DEVICES (5) 
     if (sample_position == 0) {
       println("BEGINNING DATA ACQUISITION");
     }
     for(int Ichan = 0; Ichan < NUM_CHANNELS_USED; Ichan++) {
       std_uV[sample_position][Ichan][previous_rand_index] +=  dataProcessing.data_std_uV[Ichan];

       findPeakFrequency(fftData ,Ichan);
       
     }
     sample_position++;
     if(sample_position == SAMPLE_SIZE) { //If we finish all samples, increment number of completed runs.
       num_completions++;
     }
    } else {
    }
  }
   
//********************************************************************************
//CheckStdDev
//********************************************************************************
float[] FindStdDevThreshold() {
  float[] Average = new float[NUM_CHANNELS_USED];
  float[] StdDev = new float[NUM_CHANNELS_USED];
  float[] Threshold = new float[NUM_CHANNELS_USED];
  final int NUM_POINTS = 50; //number of points to consider for threshold
  float[] Minpeak = new float[NUM_CHANNELS_USED];
  Average = FindSumandAverage();
  StdDev = FindFullDev(Average);
  Minpeak = FindPoints(NUM_POINTS);
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    Threshold[iChan] = abs(Minpeak[iChan]-Average[iChan])/StdDev[iChan];
  }
  return Threshold;
}

float[] FindPoints(final int NUM_POINTS) {
  float[][] Point_values = new float[NUM_CHANNELS_USED][NUM_POINTS];
  float[] Average = new float[NUM_CHANNELS_USED];
  float[] Min = new float[NUM_CHANNELS_USED];
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) { //Store an initial amount of values up to NUM_POINTS
    Min[iChan] = 1000;
    for(int sample_position = 0; sample_position < NUM_POINTS; sample_position++) {
      Point_values[iChan][sample_position] = Time_Data[sample_position][iChan][previous_letter_index];
    }
  }
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) { //Replace values as you slowly go through all of them.
    for(int sample_position = NUM_POINTS; sample_position < SAMPLE_SIZER; sample_position++) {
      for(int point_index = 0; point_index < NUM_POINTS; point_index++) {
        if(Time_Data[sample_position][iChan][previous_letter_index] > Point_values[iChan][point_index]) {
          Point_values[iChan][point_index] = Time_Data[sample_position][iChan][previous_letter_index];
        }
          
      }
    }
  }
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) { //Compute the average for all channels and find the minimum value.
    float temp = 0;
    for(int sample_position = 0; sample_position < NUM_POINTS; sample_position++) {
      temp += Point_values[iChan][sample_position]; 
      if(Point_values[iChan][sample_position] < Min[iChan]) {
        Min[iChan] = Point_values[iChan][sample_position];
      }
    }
    Average[iChan] = (temp/NUM_POINTS);
  }
  //for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
  //  Average[iChan] = (Average[iChan] + Min[iChan])/2;
  //}
  return Average;
}

void CheckStdDev() {
  //Find the average for each channel
  //float[] average = new float[NUM_CHANNELS_USED];
  //float[] stdDev = new float[NUM_CHANNELS_USED];
  final int excused_interval = 5; //Five excused points before considering it no longer a peak.
  int num_noPeak = 0;
  float DevDistance = 0;
  float[][] DevDistances = new float[NUM_CHANNELS_USED][SAMPLE_SIZER];
  float[][] AverageList = new float[NUM_CHANNELS_USED][SAMPLE_SIZER];
  float[][] StdList = new float[NUM_CHANNELS_USED][SAMPLE_SIZER];
  final int lag = 3; //Number of points to lag behind on.
  final float[] stdDev_thresh = FindStdDevThreshold();
  println("StdDevThresh for channel 1: " + stdDev_thresh[0] + ", Channel 2: " + stdDev_thresh[1]);
  final float influence = 0.5;
  int starting_point;
  int letter_index = previous_letter_index;
  float inf_factor = (1-influence);
  PrintRMSLog();
  //PrintTimeDataLog();
  if(first_run) { //If first run, then there is no average or std deviation yet.
    //Store for lag amount of points. This means that the system will only be able to access these "specified"
    for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
      StoreinBuffer(0,lag, inf_factor, iChan);
      averages[iChan] = CalcAverageusingBuffer(iChan); //Lagged average, add influence in here?
    }
    //println("Average first run:" + average);
    println("Average channel 1: " + averages[0] + " Average channel 2: " + averages[1]);
    stdDev = CalcStdDeviation(averages, rmsBuffer); //Lagged std deviation, add influence here? or store as already influenced value
    //println("Std dev first run:" + stdDev);
    starting_point = lag;   //Start at the lagged data point when iterating.
    
    first_run = false;
  } else { //This is another run
    starting_point = 0; //Start at sample 0.
  }
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) { //For each channel, iterate through and compute the average/std deviation to compare each and every point to see if it is above the threshold for std deviation
    for(int i = starting_point; i < SAMPLE_SIZER; i++) { //Go between starting point and 
      //println("i is " + i);
      StoreinBuffer(i,1, inf_factor, iChan); //Store one value in the buffer (for each channel separately).
      averages[iChan] = CalcAverageusingBuffer(iChan);
      //println("Average is now:" + averages[iChan]);
      stdDev = CalcStdDeviation(averages, rmsBuffer); //Make the buffer span the entire thing and only take into account cases where the rmsBuffer value is not zero.
      //println("stdDev is now:" + stdDev[iChan]);
      //println("previous letter index is : " + previous_letter_index + " but letter_index is " + previous_rand_index); //Use previous_letter_index for Time_Data, previous_rand_index for anything else
      //println("rms value " + Time_Data[i][iChan][previous_letter_index] + " averages: " + averages[iChan] + " stdDev: " + stdDev[iChan]);
      DevDistance = abs(inf_factor*Time_Data[i][iChan][previous_letter_index] - averages[iChan])/(stdDev[iChan]); 
      DevDistances[iChan][i] = DevDistance;
      AverageList[iChan][i] = averages[iChan];
      //if (iChan == 1) {
      //  println("Channel 1 Average is " + averages[iChan]);
      //}
      
      StdList[iChan][i] = stdDev[iChan];
       //println("DevDistance is:" + DevDistance);
      if(DevDistance >= stdDev_thresh[iChan] && !continuous_peak) {
        println("PEAK AT " + inf_factor*Time_Data[i][iChan][previous_letter_index] + " with a deviation distance of " + DevDistance);
        peakCount[iChan]++;
        //println("Lowest possible value for rms" + (stdDev_thresh*
        continuous_peak = true;
      } else if(DevDistance >= stdDev_thresh[iChan] && continuous_peak) {
        continuous_peak = true;
        num_noPeak = 0;
      } else {
        num_noPeak++;
        if(num_noPeak >= excused_interval) { //If the peak is lower for excused_interval # of points, then we will consider it no longer a peak.
          continuous_peak = false;
          num_noPeak = 0;
        }
        
      }
    }
  }
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    println("Peaks for channel " + iChan + ":" + peakCount[iChan]);
    peakCount[iChan] = 0;
    //float[][][] rms1 = new float[SAMPLE_SIZE][NUM_CHANNELS_USED][NUM_LETTERS_USED];
  }
  //rms1 = new float[SAMPLE_SIZE][NUM_CHANNELS_USED][NUM_LETTERS_USED];
  Time_Data = new float[SAMPLE_SIZER][NUM_CHANNELS_USED][NUM_LETTERS_USED];
  dev_run++;
  PrintTimeDataLog();
  PrintDeviationDistances(DevDistances, AverageList, StdList);
}
void PrintDeviationDistances(float[][] DevDistances, float[][] AverageList, float[][] StdList) {
  PrintWriter output;
  output = createWriter("Deviation.txt");
  for(int channel = 0; channel < NUM_CHANNELS_USED; channel++) {
         output.println("Channel " + channel);
         for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
           output.println("Sample no " + sample_position + " is " + DevDistances[channel][sample_position] + " and Average was " + AverageList[channel][sample_position] + " with a std deviation of " + StdList[channel][sample_position]); //Changed from previous_letter_index to previous_rand_index
         }
       }
       output.flush();
       output.close();
}
void PrintRMSLog() {
       PrintWriter output;
       if(first_run) {
         output = createWriter("rmslog.txt");
       } else {
         output = createWriter("Otherrmslog.txt");
       }
       for(int channel = 0; channel < NUM_CHANNELS_USED; channel++) {
         output.println("Channel " + channel);
         for(int sample_position = 0; sample_position < SAMPLE_SIZE; sample_position++) {
           output.println(rms1[sample_position][channel][previous_rand_index]); //Changed from previous_letter_index to previous_rand_index
         }
       }
       output.flush();
       output.close();

}
//void PrintTimeDataLog() {
//  PrintWriter output;
//  output = createWriter("TimeDataLog.txt");
//  for(int channel = 0; channel < NUM_CHANNELS_USED; channel++) {
//         output.println("Channel " + channel);
//         for(int sample_position = 0; sample_position < SAMPLE_SIZER*WINDOW_SIZE; sample_position++) {
//           output.println(rmsBuffer[channel][sample_position]); //Changed from previous_letter_index to previous_rand_index
//         }
//       }
//       output.flush();
//       output.close();
//}
float[] CalcStdDeviation(float[] average, float[][] rmsBuffer) {//good to use
  float[] stdDev = new float[NUM_CHANNELS_USED];
  
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    float temp = 0;
    int numpoints = 0;
    for(int i = 0; i < (SAMPLE_SIZER*WINDOW_SIZE); i++) {
      if(rmsBuffer[iChan][i] != 0) {
        temp += pow((rmsBuffer[iChan][i]-average[iChan]),2); //Add up the squares of the differences between the mean and each data point
        numpoints++;
      }
    }
    temp = temp/(numpoints-1); //Divide the sum of what was calculated earlier by the number of samples.
    stdDev[iChan] = sqrt(temp);
  }
  return stdDev;
}
float findSquareSum(int iChan) { //Finds the square sum in the standard deviation. Uses the TOTAL_SAMPLES (The number of samples we have used to obtain the standard deviation) and the squaring function
  float SquareSum = 0;
  SquareSum = pow(stdDev[iChan], 2);
  SquareSum = SquareSum*TOTAL_SAMPLES;
  return SquareSum;
}
void StoreinBuffer(int starting_point, int amount_to_store, float inf_factor, int iChan) { //Store rms1 values in a buffer that is the size of SAMPLE_SIZE*WINDOW_SIZE.
  int startpoint = SAMPLE_SIZER*(dev_run % WINDOW_SIZE) + starting_point;
  int endpoint = startpoint + amount_to_store;


    for(int i = startpoint; i < endpoint; i++) {
      int index = 0;
        //println("starting_point is " + startpoint + " and the end point is " + endpoint);
        rmsBuffer[iChan][i] = (inf_factor*Time_Data[starting_point][iChan][previous_letter_index]); //Store information accordingly.
        //println("Buffer value is: " + rmsBuffer[iChan][i] + " and Time_Data value is " + Time_Data[starting_point][iChan][previous_letter_index]);
      starting_point++;
    }
  
}
//float[] CalcAverage(int sample_max, float inf_factor) { //Lag function, good to go
//  float[] sum = new float[NUM_CHANNELS_USED];
//  float[] average = new float[NUM_CHANNELS_USED];
//  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
//    for(int i = 0; i < sample_max; i++) {
//      sum[iChan] += inf_factor*Time_Data[i][iChan][previous_letter_index];
//    }
//    average[iChan] = (sum[iChan]/sample_max);
//  }
//  return average;
//}

float CalcAverageusingBuffer(int iChan) {
  float Average = 0;
  float temp = 0;
  int numpoints = 0;
  for(int i = 0; i < SAMPLE_SIZER*WINDOW_SIZE; i++) {
    if(rmsBuffer[iChan][i] != 0) {
      temp += rmsBuffer[iChan][i];
      //println("Buffer value is " + rmsBuffer[iChan][i]);
      numpoints++;
    }
  }
  //if(iChan == 1) {
  //  println("Temp is " + temp + " with a point count of " + numpoints);
  //}
  Average = (temp/numpoints);
 return Average;
}
float iterateAverage(float average, float rms) { //Iterates to get new average value.
  average = (average + rms)/2;
  return average;
}
//********************************************************************************
//CheckRMS, checks to see if the threshold values to see if any RMS values are above them
//********************************************************************************
//void CheckRMS() { //Basic one/two tongue tap movement detection function
//  //rms1[sample_position][Ichan][previous_rand_index]
//  int peakcount = 0;
//  int oneTap = 0;
//  int twoTap = 0;
//  boolean currentlyinpeak = false;
//  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
//    for(int i = 0; i < SAMPLE_SIZE; i++) {
//      println("rms value of sample " + i + " for channel " + iChan + " is " + rms1[i][iChan][previous_rand_index]);
//      if((rms1[i][iChan][previous_rand_index]*1000) > thresh[iChan] && currentlyinpeak == false) { //Change uV to nV (essentially) by multiplying by 1000 to compare with the threshold of each channel.
//        peakcount++;
//        currentlyinpeak = true;
//        println("Count incremented");
//      } else if((rms1[i][iChan][previous_rand_index]*1000) < thresh[iChan] && currentlyinpeak == true) { //Consider it no longer in the peak.
//        currentlyinpeak = false;
//      }
//    }
//    if(peakcount == 1) {
//      //Increment one tongue tap variable
//      oneTap++;
//    } else if(peakcount == 2) {
//      //Increment two tongue tap variable
//      twoTap++;
//    } else {
//      //Invalid result.
//      println("Invalid channel...");
//    }
//    println("Peak Count for " + iChan + " is " + peakcount);
//    peakcount = 0;
//  }
//    if(oneTap > twoTap) { //Try taking rates of change in order to determine whether or not there is a peak. Maybe search up how to determine the tangent lines for each point.
//      //Identify as one tongue tap
//      println("One tongue tap");
//    } else if (twoTap > oneTap) {
//      //Identify as two tongue tap
//      println("Two tongue tap");
//    } else {
//    println("One tap");
//  } else if (peakCount[0] == 2) {
//    println("Two taps");
//  } else {
//    println("Invalid...");
//  }
//}
//int AnalyzeSlopes(float[][] slope) { //Find the number of peaks prevalent, version 1
//  boolean[][] slopeMap = new boolean[SAMPLE_SIZE][NUM_CHANNELS_USED]; 
//  boolean PosSlopeofPeak = false;
//  boolean NegSlopeofPeak = false;
//  final int X = 3;
//  int peakCount = 0;
//  int consecPosSlopes = 0;
//  int consecNegSlopes = 0;
//  slopeMap = mapSlopes(slope);
  
//  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
//    for(int i = 0; i < SAMPLE_SIZE; i++) {
      
//      if(slopeMap[i][iChan] == true) {
//        consecPosSlopes++;
//        if(consecPosSlopes > X) { //If there are more than X points that have a positive slope, then consider it the positive increasing portion of the peak.
//          PosSlopeofPeak = true;
//          consecPosSlopes = 0;
//        }
//        consecNegSlopes = 0;
//      } else {
//        consecNegSlopes++;
//        if(consecNegSlopes > X) { //If there are more than X points that have a negative slope, then consider it the negative decreasing portion of a peak.
//          NegSlopeofPeak = true;
//          consecNegSlopes = 0;
//        }
//        consecPosSlopes = 0;
//      }
//      if((NegSlopeofPeak == true) && (PosSlopeofPeak == true)) {
//        println("Peak detected.");
//        peakCount++;
//      }
//    }
//  }
//}
//      println("No detection...");
//    }
//}
//void checkRateRMS () { //Option 4. It uses slope to find peaks.
//  float[][] slope = new float[SAMPLE_SIZE][NUM_CHANNELS_USED];
//  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
//    for(int i = 0; i < SAMPLE_SIZE-1; i++) {
//      slope[i][iChan] = (rms1[i+1][iChan][previous_letter_index] - rms1[i][iChan][previous_letter_index]);
//    }
//  }
//  int[] peakCount = new int[NUM_CHANNELS_USED];
//  peakCount = AnalyzeSlopes(slope); //Find the number of peaks.
//  println("There are " + peakCount[0] + " peaks.");
//  if(peakCount[0] == 1) {
int[] AnalyzeSlopes(float[][] slope) { //Version 2 of finding peaks. Finds the number of peaks prematurely, which are processed to find real peaks in another function. Returns the # of real peaks.
  boolean[][] slopeMap = new boolean[SAMPLE_SIZE-1][NUM_CHANNELS_USED];
  int[] peakCount = new int[NUM_CHANNELS_USED];
  int[] peakindices = new int[SAMPLE_SIZE]; //make a dynamic array for ease of use?
  int[] peakChannels = new int[SAMPLE_SIZE];
  int PointsforPeak = 0;
  final int X = 3;
  final float rms_thresh = 13;
  slopeMap = mapSlopes(slope); //returns a mapping for slopes (in terms of boolean)
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    for(int i = 0; i < SAMPLE_SIZE-1; i++) { //0-1, 1-2, 2-3, 3-4, 4-5, 5-6, 6-7, 7-8, 8-9, 9-10, 10-11, 11-12, 12-13, 13-14, 14-15, 15-16, 16-17, 17-18, 18-19, 19-20, 20-21, 21-22, 22-23, 23-24
      int minDistancefromEdge = FindDistance(i, SAMPLE_SIZE);
      //for(int j = 1; j < minDistancefromEdge; j++) {
        if((slopeMap[i][iChan] == true) && (slopeMap[i+1][iChan] == false)) {
          //println("Peak found at sample " + (i+1) + " at distance " +  + " away.");
          boolean PeakorNot;
          PeakorNot = VerifyPeak(i, iChan, slopeMap); //Verify whether or not this peak is really a peak
          if (PeakorNot == true && (rms1[i+1][iChan][previous_letter_index]*1000) > rms_thresh) { //Count it as a peak, disregard all others.
            peakCount[iChan]++; //Increment the number of points that seem to indicate a peak.
            println("rms value at the peak for channel " + iChan + " is " + rms1[i+1][iChan][previous_letter_index]);
          }
        }
         //if(PointsforPeak >= X) { //If we have X number of points that indicate a peak, then consider it a peak.
         //  peakindices[peakCount] = i;
         //  peakChannels[peakCount] = iChan;
         //  peakCount++;
         //  PointsforPeak = 0;
         //}
       }
    }
  //}
  return peakCount;
}

boolean VerifyPeak(int sample_position, int sample_chan, boolean[][] slopeMap) { //Takes in the peak found in the prior function AnalyzeSlopes and searches to see if there are enough positive and negative slopes around the peak to consider it a real peak.
  int minDistancefromEdge = FindDistance(sample_position, SAMPLE_SIZE);
  int PosSlopeCount = 0;
  int NegSlopeCount = 0;
  final int X = 3; //Number of slopes that have to be verified for the peak to be valid.
  if(minDistancefromEdge >= X) {
    for(int j = 1; j < minDistancefromEdge; j++) {
      if (slopeMap[sample_position-j][sample_chan] == true) { //Check if the slope is positive. If it is, then increment the number of pos slopes. If not, return false.
        println("check " + j + " for positive slope good.");
        PosSlopeCount++;
        println("Positive Slope Count now " + PosSlopeCount);
      } else {
        println("Returning false");
        return false; //
      }
      
      if (slopeMap[sample_position+j][sample_chan] == false) { //Check if the slope is negative. Same as above. If not, return false.
        println("check " + j + " for negative slope good.");
        NegSlopeCount++;
        println("Negative slope Count now " + NegSlopeCount);
        if(PosSlopeCount == X && NegSlopeCount == X) { //Quota of # of valid slopes has been reached.
          println("returning true for channel " + sample_chan);
          return true;
        }

      } else {
        println("returning false");
        return false;
      }
    }
  } else {
    return false; //Not enough points to be considered.
  }

  return false;
}

int FindDistance(int i, int SAMPLE_SIZE) { //Finds the distance from the boundaries with respect to the current sample's position.
  int[] DistancefromEdge = new int[2]; //DistancefromEdge[0] will be the distance from the current point to the beginning. DistancefromEdge[1] will e the distance from the current point to the end.
  DistancefromEdge[0] = i;
  DistancefromEdge[1] = SAMPLE_SIZE-i;
  if(DistancefromEdge[0] <= DistancefromEdge[1]) {
    return DistancefromEdge[0];
  } else {
    return DistancefromEdge[1];
  }
}
boolean[][] mapSlopes(float[][] slope) { //Maps the slope out in boolean
  boolean[][] slopeMap = new boolean[SAMPLE_SIZE][NUM_CHANNELS_USED]; //If slopeMap is true, then it is a positive slope. If false, then it is a negative slope.
  for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
    for(int i = 0; i < SAMPLE_SIZE-1; i++) {
      if(slope[i][iChan] > 0) {
        slopeMap[i][iChan] = true;
      } else {
        slopeMap[i][iChan] = false;
      }
    }
  }
  return slopeMap;
}
//*******************************************
//Function to find highest hit count
//*******************************************
 int findSecondHighestHit (int[] hit_count) {
     int hit_count_max = 0;
     int max_hit_counts_index = 0;
     int prev_max_hit_index = 0;
     for(int letter_position = 0; letter_position < NUM_LETTERS_USED; letter_position++) { //5 represents the number of characters.
       if(hit_count[letter_position] > hit_count_max) {
         prev_max_hit_index = hit_count_max;
         hit_count_max = hit_count[letter_position];
         max_hit_counts_index = letter_position;
       }
     }
     return prev_max_hit_index;
   }
 int findMaxHits1(int[] hit_count) {
     int hit_count_max = 0;
     int max_hit_counts_index=0;
     for(int letter_position = 0; letter_position < NUM_LETTERS_USED; letter_position++) { //5 represents the number of characters.
       if(hit_count[letter_position] > hit_count_max) {
         hit_count_max = hit_count[letter_position];
         max_hit_counts_index = letter_position;
       }
     }
     return max_hit_counts_index;
   }
//*******************************************
//Function to play voice commands.
//*******************************************
   void VoiceCommand(int letter_to_trigger) {
     device_to_play = letter_to_trigger;
     thread("Trigger");
     //println("Trigger on letter index " + device_to_play);
     //println("Done with command");
     sample_position = 0;
     wait = true; //Set the delay of the flashing to the amount specified by the waits.
     datafilled = false;
     //Reinitialize arrays below.
   }

//*********************************************
//Meant to load in data.
//*********************************************
   //ORIGINAL METHOD TO LOAD INT TEST DATA BELOW.
   void loadTestData1() {
     BufferedReader reader;
     String line;
     final float AMP_THRESH = 0.3;
     final float STD_DEV_THRESH = 25;
     //float factor = 24f;
     //Loads in from test file into the arrays below. From there, it compares with the recently collected data to classify.
     //1) Read from text file?
     //2) Store in Data array
     //3) Or, you can try storing directly when initialized (meaning this function isn't needed).
     float[][] CompData_chan = new float[NUM_CHANNELS_USED][MAX_DATA_SIZE];
     boolean[][] Target_chan = new boolean[NUM_CHANNELS_USED][MAX_DATA_SIZE];
     //float [] baseline_avg = new float[NUM_CHANNELS_USED]; 
     int[] sample_locations = new int[MAX_DATA_SIZE];
     reader = createReader("classify2.txt"); //Enter text file you want to use here.
     
     //NormalizeData(previous_letter_index); //Normalizes the data from 0 to 1.
     float[] Average = new float[NUM_CHANNELS_USED];
     float[] StdDev = new float[NUM_CHANNELS_USED];
     Average = FindSumandAverage();
     StdDev = FindFullDev(Average);
     float AvgDev = AverageDev(StdDev);
     if(AvgDev > STD_DEV_THRESH) { //Only do stuff if it is above the threshold.
       FixData();
        //Take in the first line to get baseline values.
         //try {
         //  line = reader.readLine();
         //} catch (IOException e) {
         //    e.printStackTrace();
         //    line = null;
         //}
         //String[] piece = split(line, " ");
         //for(int i = 0; i < NUM_CHANNELS_USED; i++) {
         //  baseline_avg[i] = float(piece[i]);
         //}
         
        //TRY TO MAKE THIS READING INTO A FUNCTION SO THAT WE CAN STOP PUTTING THESE STATEMENTS
         //try {
         //  line = reader.readLine(); 
         //} catch (IOException e) {
         //    e.printStackTrace();
         //    line = null;
         //}
         //int MAX_SAMPLES = int(line);
         //println("Number of samples: " + MAX_SAMPLES);
         //int[] sample_locations = new int[MAX_SAMPLES]; //Stores the sample position of each recorded sample.
       for(int sample_position = 0; sample_position < MAX_DATA_SIZE; sample_position++) {
         try {
           line = reader.readLine();
         } catch(IOException e) {
            e.printStackTrace();
            line = null;
         }
         if(line == null) {
           break; //stop reading.
         } else {
           String[] pieces = split(line, " ");
           //Shrink this down to only a single class (for each channel) once initial testing is done.
           sample_locations[sample_position] = int(pieces[0]);
           for (int i = 0; i < NUM_CHANNELS_USED; i++) {
             CompData_chan[i][sample_position] = float(pieces[2*i+1]); //CompData specifies the amplitude axis.
             Target_chan[i][sample_position] = boolean(pieces[(2*i)+2]);
           }
           //CompData_chan0[sample_position] = float(pieces[0])*factor;
           //Target_chan0[sample_position] = boolean(pieces[1]);
         }
       }
       
       int[] Letter_count = new int[NUM_LETTERS_USED];
       println("Using results from letter index " + previous_letter_index);
           for (int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) { //Change to match the amount of samples.
             //Note: rather than sending in time, it is much easier to send in the sample and calculate the time in the KNN algorithm, though we can change it later.
             //Index for device_choice
             for (int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
               if (iChan == IgnoreChan) { //Do nothing...
               } else {
  
               //Each letter will be checked individually, for the highest count. Letters in this case are the device we want to choose.
               float amplitude = (Time_Data[sample_position][iChan][previous_letter_index]);
               if(abs(amplitude) > AMP_THRESH) {
                  int Sentence_choice = KNNAlgorithm(CompData_chan[iChan], Target_chan[iChan], amplitude, sample_position, sample_locations);
                 switch (Sentence_choice) { //Choose based on KNNAlgorithm return: if 0, we increment A. If 1, we increment B.
                 case 0:
                   Letter_count[0]++;
                   break;
                 case 1:
                   Letter_count[1]++;
                   break;
                 default:
                   Letter_count[2]++;
                 break;
                 } 
               } else { //Do nothing...
                 
               }
               
               }
             }
           }
         //}
         for (int letter_index = 0; letter_index < NUM_LETTERS_USED; letter_index++) {
           println("Hitcount for letter " + letter_index + " is " + Letter_count[letter_index]);
         }
         //int max_hitcount = findMaxHits(Letter_count); //Find highest hit count.
         int maxindex = findMaxHits1(Letter_count);
         int secondhighestindex = findSecondHighestHit(Letter_count);
         
         println("Index chosen is " + maxindex);
           VoiceCommand(maxindex);
           w_p300speller.WordTrigger = true;
           w_p300speller.Word_index = maxindex;
         //}
           for(int iChan = 0 ; iChan < NUM_CHANNELS_USED; iChan++) {
             println("Std Deviation for Channel " + iChan + ":" + StdDev[iChan]);
           }
         PrintTimeDataLog();
     } else {
     }
   }
//*******************************************************************
//Save data
//*******************************************************************
   //Original SaveData
   void saveData1() {
     PrintWriter output;
     //float factor = 24f;
     output = createWriter("classify2.txt");
     //Save the initial averaged values into the file first.
     //String preline = "";
     //for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
     //  preline += average[iChan];
     //  preline += " ";
     // }
      //output.println(infoline); //Output the infoline into the file. CHANGE THE LOADTESTDATA TO MATCH THIS.
      int sample_number;
      //for(int l_index = 0; l_index < NUM_LETTERS_USED-1; l_index++) {
        sample_number = 0;
        
        for(int data_position = 0; data_position < MAX_DATA_SIZE; data_position++) { //Up to 200, that is the amount of samples stored in the text file.
         //print data for each sample (of each channel) on the same line. The way it is stored in the file.
           if((data_position % SAMPLE_SIZER) == 0) { //Start at sample no 0 after the max number of samples have been reached.
             sample_number = 0;
           }
 
           String line = "";
           line += sample_number;
           line += " ";
           
           for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
             if(abs(Stored_Data[iChan][data_position]) > 0) { //Do everything normally
               //Do nothing
             } else {
               Stored_Data[iChan][data_position] = 0; //Store the data in that position as 0.
             }
              line += (Stored_Data[iChan][data_position]); //Print the data we have collected, as well as whether or not it is letter A or B.
              line += " ";
              line += (TargetOrNot[iChan][data_position]);
              line += " ";
            }
            sample_number++;
          output.println(line);  
           //output.println(Stored_Data[0][data_position] + " " + TargetOrNot[0][data_position] + " " + Stored_Data[1][data_position] + " " + TargetOrNot[1][data_position] + " " + Stored_Data[2][data_position] + " " + TargetOrNot[2][data_position] + " " + Stored_Data[3][data_position] + " " + TargetOrNot[3][data_position] + " " + Stored_Data[4][data_position] + " " + TargetOrNot[4][data_position] + " " + Stored_Data[5][data_position] + " " + TargetOrNot[5][data_position] + " " + Stored_Data[6][data_position] + " " + TargetOrNot[6][data_position] + " " + Stored_Data[7][data_position] + " " + TargetOrNot[7][data_position] + " " + Time[0][data_position] + " " + Time[1][data_position] + " " + Time[2][data_position] + " " + Time[3][data_position] + " " + Time[4][data_position] + " " + Time[5][data_position] + " " + Time[6][data_position] + " " + Time[7][data_position]);  
          }
      //}
     output.flush();
     output.close();
     PrintIndividualPiecesOfData();
   }
void PrintIndividualPiecesOfData() { //Meant to output the data of each channel so that we can actually plot them to see if they're doing what's intended.
     PrintWriter output;
     String[] Filenames = {"Channel1.txt", "Channel2.txt", "Channel3.txt", "Channel4.txt", "Channel5.txt", "Channel6.txt", "Channel7.txt", "Channel8.txt"};
     for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
       output = createWriter(Filenames[iChan]);
       for(int data_position = 0; data_position < MAX_DATA_SIZE; data_position++) {
         String line = "";
         line += Stored_Data[iChan][data_position];
         output.println(line);
       }
       output.flush();
       output.close();
     }
     println("Finished Saving Data");
}
int findMaxSetLength(int [] SetLength) {
  int maxSetLength = 0;
  for (int letter = 0; letter < NUM_LETTERS_USED-1; letter++ ) {
    if(SetLength[letter] > maxSetLength) {
      maxSetLength = SetLength[letter];
    }
  }
  return maxSetLength;
}
//************************************************************************
//KNN Algorithm
//************************************************************************
   
   int KNNAlgorithm(float[] Data, boolean[] TargetorNot, float amplitude, int sample_position, int[] sample_locations){ //ADD IN MAX_SAMPLES AS A VARIABLE THAT IS PASSED IN, SO THAT WE CAN MAKE THE FOR LOOP RUN PROPERLY.
   for (int i = 0; i < N; i++) {
      CompData[i] = new MinimumIndices();
      CompData[i].MinDistance = 100000; //Dummy Initialization.
    }
   float distance = 0;
   int data_position = 0;
   //Change i < to i < MAX_DATA_SIZE once done
   for (int i = 0; i < MAX_DATA_SIZE ; i++) { //For each data point in the test samples, compute the distance.
     float x = pow(((Data[i])-(amplitude)),2); //Compute the distance (for x on this line) between the points in data and the recently acquired data.
     data_position = sample_locations[i];
     float y = pow(((float(data_position)/SAMPLE_SIZER) - (float(sample_position)/SAMPLE_SIZER)),2);
     distance = sqrt(x+y);
     //println("Distance: " + distance);
     //Add multiple indices depending on the amount of checks we want to perform. For loop with N classifications.
     for (int j = 0; j < N; j++) { //For each index up to N, check if distance < minindex.distance to find the N closest samples.
       if (distance < CompData[j].MinDistance){
         CompData[j].MinDistance = distance;
         CompData[j].MinIndex = i;
         CompData[j].target = TargetorNot[i];
       }
     }
    //} else {
    //  println("Data was 'invalid'");
    //}
   }
     int hit_count_target = 0;
     int hit_count_nottarget = 0;
     for(int j = 0; j < N; j++) {
       if(CompData[j].target) {
         hit_count_target++;
       } else {
         hit_count_nottarget++;
       }
     }
     //println("Hit count: " + hit_count_target);
     //println("Not Hit Count: " + hit_count_nottarget);
    if(hit_count_target > hit_count_nottarget) {
      return 1; //If 1, then it increments the letter_count, making us decide which letter is the right one. Else, it does not increment.
    } else {
      return 0;
    }
   }
//************************************************************************
//CheckSamples, checks to see which sets of the samples are valid.
//************************************************************************
int CheckSamples (float[] baseline_avg, int letter_index) { //Find the sets that are higher than the baseline average
  int SetToReturn = NO_SET;
  boolean HasbeenSet = false;
  for(int setno = 0; setno < NUM_SETS; setno++) {
    int NCaT = 0; //Stands for Numbers of Channels above threshold (baseline average)
    for(int iChan = 0; iChan < NUM_CHANNELS_USED; iChan++) {
      float average = 0;
      switch(option) {
      case 1:
        average = SumandAverage(Time_Data, setno, iChan, letter_index);
      case 2:  //Real time analysis
        average = SumandAverage(Time_Data, setno, iChan, letter_index);
        break;
      default:
        break;
      }
      println("Average is " + average + ". Baseline average is " + baseline_avg[iChan]);
      if(average > baseline_avg[iChan]) { //If the average from this set is greater than the baseline, then increment NCaT.
        NCaT++;
      }
    }
    if((NCaT > (NUM_CHANNELS_USED/2)) && (HasbeenSet == false)) { //Consider the set, since more than half of the channels used are greater than baseline. This is the first set
      SetToReturn = setno;
      println("Set identified at set number: " + SetToReturn);
      HasbeenSet = true;
      IncrementSetLength();
    } else if((NCaT > (NUM_CHANNELS_USED/2)) && (HasbeenSet == true)) { //If this set is to be considered, but there is already another set prior, then we will increment set length.
      IncrementSetLength();
      println("Incremented Set Length");
    } else if ((NCaT <= (NUM_CHANNELS_USED/2)) && (HasbeenSet == true)){ //(NOTE TO SELF: MAKE THIS INTO A CONDITIONAL STATEMENT THAT MAYBE ENDS THE FUNCTION AFTER THE SET WE WERE LOOKING AT IS NO LONGER CONSIDERED CONTINUOUS)Else, if NCaT is not > half the number of channels used, then we reset SetToReturn, and continue until the end
      //SetToReturn = NO_SET; //Set to NO_SET, which represents the fact that there is no possible set at this moment in time.
      //
      println("Set construction complete.");
      println("Returning set number " + SetToReturn + " with length of " + SetLength);
      return SetToReturn; //Return the set, it is complete.
    } else {
      SetToReturn = NO_SET; //No set yet... continue searching.
      println("Nothing yet, continue searching...");
    }
    NCaT = 0; //Reset NCaT, so that we can repeat the process.
  }
  return SetToReturn; //Return the set, if it hasn't done so already.
}

float SumandAverage(float[][][] Time_Data, int setnum, int channelnumber, int letter_index) { //Sum and average the set we are looking at.
  float sum = 0;
  for(int sample_position = (setnum*(SAMPLE_SIZER/NUM_SETS)); sample_position < ((setnum+1)*(SAMPLE_SIZER/NUM_SETS)); sample_position++) { //Starts at the start of a set and ends at the end of its set.
    sum += Time_Data[sample_position][channelnumber][letter_index];
  }
  float average = sum/(SAMPLE_SIZER/NUM_SETS);
  return average;
}
void IncrementSetLength() {
  SetLength++;
}
void ResetSetLength() { //Maybe change this function into a general reset function, so things are kept much more clean.
  SetLength = 0;
}
int GetSetLength() {
  return SetLength;
}
//************************************************************************
//CheckSamplelength, self-explanatory, finds the number of sets that are used.
//************************************************************************
//**********************************************************
//Frequency-Domain Analysis
//**********************************************************
  //Finds Peak Frequency, among some other information. Taken from EEG Processing.
   void findPeakFrequency(FFT[] fftData, int Ichan) {

    //loop over each EEG channel and find the frequency with the peak amplitude
    float FFT_freq_Hz, FFT_value_uV;
    //for (int Ichan=0;Ichan < n_chan; Ichan++) {

    //clear the data structure that will hold the peak for this channel
    detectedPeak[Ichan].clear();

    //loop over each frequency bin to find the one with the strongest peak
    int nBins =  fftData[Ichan].specSize(); //Note what this does.
    for (int Ibin=0; Ibin < nBins; Ibin++) {
      FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin); //here is the frequency of htis bin

        //is this bin within the frequency band of interest?
      if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
        //we are within the frequency band of interest

        //get the RMS voltage (per bin)
        FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins); 
        
        //FFT_value_uV = fftData[Ichan].getBand(Ibin);
        
        //decide if this is the maximum, compared to previous bins for this channel
        if (FFT_value_uV > detectedPeak[Ichan].rms_uV_perBin) {
          //this is bigger, so hold onto this value as the new "maximum"
          detectedPeak[Ichan].bin  = Ibin;
          detectedPeak[Ichan].freq_Hz = FFT_freq_Hz;
          detectedPeak[Ichan].rms_uV_perBin = FFT_value_uV;
        }
      } //close if within frequency band
    } //close loop over bins
    // Store rms value and average over the number of trials.
      switch(option) {
      case 1:
        rms1[sample_position][Ichan][previous_rand_index] += detectedPeak[Ichan].rms_uV_perBin; //Multiply by 10000 to avoid truncation.
        break;
      case 2:
        rms[sample_position][Ichan] += detectedPeak[Ichan].rms_uV_perBin;
        break;
      case 3:
        rms1[sample_position][Ichan][previous_rand_index] += detectedPeak[Ichan].rms_uV_perBin;
        break;
      case 4:
        rms1[sample_position][Ichan][previous_rand_index] += detectedPeak[Ichan].rms_uV_perBin;
        break;
       case 5:
         rms1[sample_position][Ichan][previous_rand_index] += detectedPeak[Ichan].rms_uV_perBin;
         //println("Stored rms value of " + rms1[sample_position][Ichan][previous_rand_index]);
         break;
      default:
        break;
      }
    //println("Raw RMS :" + detectedPeak[Ichan].rms_uV_perBin + " FOR TRIAL # " + trial_count + " ON ICHAN # " + Ichan);
    //println("Rms of signal " + "sample position " + sample_position + " is: " + rms[sample_position][Ichan][previous_rand_index] + " FOR TRIAL # " + trial_count + " ON ICHAN # " + Ichan);
    //loop over the bins again (within the sense band) to get the average background power, excluding the bins on either side of the peak
    float sum_pow=0.0;
    int count=0;
    for (int Ibin=0; Ibin < nBins; Ibin++) {
      FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin);
      if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
        if ((Ibin < detectedPeak[Ichan].bin - 1) || (Ibin > detectedPeak[Ichan].bin + 1)) {
          FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);  //get the RMS per bin
          sum_pow+=pow(FFT_value_uV, 2.0f);
          count++;
        }
      }
    }
    //compute mean
    detectedPeak[Ichan].background_rms_uV_perBin = sqrt(sum_pow / count);
    //NEWLY ADDED BACKGROUND ARRAY BELOW TO KEEP TRACK OF VALUES.
    background_rms[sample_position][Ichan][previous_rand_index] += sqrt(sum_pow/count);
    //println("Background rms of " + "sample position " + sample_position + " is: " + background_rms[sample_position][Ichan][previous_rand_index] + " for rand_index: " + previous_rand_index + " FOR TRIAL # " + trial_count + " ON ICHAN # " + Ichan);
    //decide if peak is big enough to be detected
    detectedPeak[Ichan].SNR_dB = 20.0f*(float)java.lang.Math.log10(detectedPeak[Ichan].rms_uV_perBin / detectedPeak[Ichan].background_rms_uV_perBin);
    //println("SNR: " + detectedPeak[Ichan].SNR_dB);
       //} // end loop over channels
  } //end method findPeakFrequency
}
   
 void Collect(){
    //IMPORTANT TO USE IF WE WANT ALL SAMPLES.
    int run_count = 0;
    final int numSeconds = 5;
    final int numPoints = 1250;
    int p = 0;
    index = previous_letter_index; //Check if it is previous_rand_index or previous_letter_index.
    println("On letter index " + index );
    println("DataBuffer has a size of " + dataBuffY_filtY_uV[0].length);
    final float timeBetweenPoints = (float)numSeconds / (float)numPoints;
    for(int channelNumber = 0; channelNumber < NUM_CHANNELS_USED; channelNumber++) {
    //for(int channelNumber = 0; channelNumber < 8; channelNumber++) {
      if(dataBuffY_filtY_uV[channelNumber].length > numPoints){
        if (Cnum_runs == 0) { 
        //for (int i = 750; i < dataBuffY_filtY_uV[channelNumber].length; i++) { //For the first run
        for (int i = 750; i < dataBuffY_filtY_uV[channelNumber].length; i++) { //For short stimulus.
          float time = -(float)numSeconds + (float)(i-(dataBuffY_filtY_uV[channelNumber].length-1250))*timeBetweenPoints + 2;
          //750-(-750*Cnum_runs)
          //dataBuffY_filtY_uV[channelNumber].length-(-750*Cnum_runs)
          if(p < 500) {
          //if(p <250){ //For short stimulus.
            //println("Test data 1 : " + dataBuffY_filtY_uV[channelNumber][i]);
            Time_Data[p++][channelNumber][previous_letter_index] += dataBuffY_filtY_uV[channelNumber][i]; //add to slowly get rms.
            if(previous_letter_index == baseline) {
              sum[channelNumber] += (dataBuffY_filtY_uV[channelNumber][i]/SAMPLE_SIZER);
            }
            //println("Time Data is: " + Time_Data[p-1][channelNumber][previous_letter_index]);
          }
        }
        //p = 0;
      } else {
        for (int i = 1500; i < dataBuffY_filtY_uV[channelNumber].length; i++) { //For short stimulus.
          float time = -(float)numSeconds + (float)(i-(dataBuffY_filtY_uV[channelNumber].length-1250))*timeBetweenPoints + 2;
          //750-(-750*Cnum_runs)
          //dataBuffY_filtY_uV[channelNumber].length-(-750*Cnum_runs)
          if(p < 500) {
          //if(p <250){ //For short stimulus.
            //println("Test data 1 : " + dataBuffY_filtY_uV[channelNumber][i]);
            Time_Data[p++][channelNumber][previous_letter_index] += dataBuffY_filtY_uV[channelNumber][i]; //add to slowly get rms.
            if(previous_letter_index == baseline) {
              sum[channelNumber] += (dataBuffY_filtY_uV[channelNumber][i]/SAMPLE_SIZER);
            }
            //println("Time Data is: " + Time_Data[p-1][channelNumber][previous_letter_index]);
          }
        }
        //p = 0;
      }
    }
    //stopButtonWasPressed();
    p = 0;
  }
    Col_compl = true;
    //PrintTimeDataLog();
    Cnum_runs++;
 }
void PrintTimeDataLog() {
   PrintWriter output;
       if (Cnum_runs == 0) {
         output = createWriter("logg.txt");
       } else {
         output = createWriter("logg1.txt");
       }
       for(int channel = 0; channel < NUM_CHANNELS_USED; channel++) {
         output.println("Channel " + channel);
         for(int sample_position = 0; sample_position < SAMPLE_SIZER; sample_position++) {
           output.println(Time_Data[sample_position][channel][previous_letter_index]);
           //output.println(sample_position);
         }
       }
       output.flush();
       output.close();
       
        //println("rms test from letter D #: " + (rms[10][0]/NUM_OF_TRIALS));
       println("Finished Printing Data for " + previous_letter_index + ". Test value of " + Time_Data[10][0][previous_letter_index]);
       //rms = new float[SAMPLE_SIZE][NUM_CHANNELS_USED];
       Time_Data = new float[SAMPLE_SIZER][NUM_CHANNELS_USED][NUM_LETTERS_USED];
}
//void startClient() {
//  myClient = new Client(this, "127.0.0.1", 10007);
//}
//void Write(float[][][] Time_Data, int previous_letter_index) {
//  myClient.write(str(SAMPLE_SIZER) + "/" + str(NUM_CHANNELS_USED) + "/"); //Write over the size of our entire data collection, maybe write over the amount of channels there are?
//  for(int nChan = 0; nChan < NUM_CHANNELS_USED; nChan++) {
//    for(int i = 0; i < SAMPLE_SIZER; i++) {
//      myClient.write(str(Time_Data[i][nChan][previous_letter_index]) + "/"); //Send the data for that sample, and separate each sample with a / to indicate the end of the sample.
//    }
//    //myClient.write("\"); //Indicate that the data on this channel is now complete
//  }
  
//}