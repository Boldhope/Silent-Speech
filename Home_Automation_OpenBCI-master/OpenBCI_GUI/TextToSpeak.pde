
/*This class serves to produce voices to activate smart devices in the home. Add
in the variation of which device depending on the time.*/
// ---- Define variables for indices that represent specific smart devices. Probably not the best idea, but we can implement a GUI to choose these things in the future
public class TextToSpeak {
  boolean state;
  String item;
  TTS tts;
}
final int MAX_DEVICES = 5;
final int SMART_LOCK = 3; //Case of smart lock
TextToSpeak[] Device = new TextToSpeak[MAX_DEVICES]; //Declare TextToSpeak objects
/*This class serves to produce voices to activate smart devices in the home. Add
in the variation of which device depending on the time.*/
// ---- Define variables for indices that represent specific smart devices. Probably not the best idea, but we can implement a GUI to choose these things in the future
//final int SMART_BULB = 1;
  void Initialize(TextToSpeak tts, String dname) { //Initialize the TextToSpeak object with a device name, state to 0, and creating an actual object for tts.
    tts.state = false;
    tts.item = dname;
    tts.tts = new TTS();
  }
  void Trigger() {
    TextToSpeak tts = Device[device_to_play];
    String sentence = "";
    switch(device_to_play) {
      case SMART_LOCK:
      if (tts.state == false) {
        sentence = "Alexa, ask August to lock " + tts.item;
        tts.tts.speak(sentence);
        tts.state = true;
      } else {
        sentence = "Alexa, ask August to unlock " + tts.item + " Pin: 1 2 3 4";
        tts.tts.speak(sentence);
        tts.state = false;
      }
      break;
      default:
      //Normal devices (plugs/smart bulb), turn on and off
        if (tts.state == false) { //Enter if the state of the device is OFF
         sentence = "Alexa, turn on " + tts.item;
         tts.tts.speak(sentence); //Perform TTS.
         tts.state = true; //Set state to ON.
        } else { //Enter if the state of the device is ON
         sentence = "Alexa, turn off " + tts.item;
         tts.tts.speak(sentence);
         tts.state = false; //Set state to OFF.
        }
      break;
    }
  }
/*
TextToSpeak Device = new TextToSpeak[MAX_DEVICES] Create TextToSpeak objects up to the
amount of devices we have.*/