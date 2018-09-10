
class Device{
  
  protected boolean state;
  protected String deviceName;
  protected String interactionSentence;
  
  protected String deactivatePrefix, deactivatePostfix;
  protected String activatePrefix, activatePostfix;
  
  Device(String name) {
    deviceName = name;
    state = false;  // off
    deactivatePrefix = "Turn off the";
    deactivatePostfix = "";
    activatePrefix = "Turn on the";
    activatePostfix = "";
    rebuildInteractionSentence();
  }
  
  String rebuildInteractionSentence() {
    if(state) {
      interactionSentence = deactivatePrefix + " " + deviceName + " " + deactivatePostfix;
    } else {
      interactionSentence = activatePrefix + " " + deviceName + " " + activatePostfix;
    }
    
    return interactionSentence;
  }
  
  String interactWithDevice() {
    rebuildInteractionSentence();
    state = !state;
    return interactionSentence;
  }
  
  void setDeactivatePrefix(String s) {
    deactivatePrefix = s;
    rebuildInteractionSentence();
  }
  
  void setDeactivatePostfix(String s) {
    deactivatePostfix = s;
    rebuildInteractionSentence();
  }
  
  void setActivatePrefix(String s) {
    activatePrefix = s;
    rebuildInteractionSentence();
  }
  
  void setActivatePostfix(String s) {
    activatePostfix = s;
    rebuildInteractionSentence();
  }
}

class SmartLock extends Device {
  
  String pinCode;
  
  SmartLock(String name, String pin) {
    super(name);
    pinCode = pin;
    deactivatePrefix = "Ask August to unlock";
    deactivatePostfix = "";
    activatePrefix = "Ask August to lock";
    activatePostfix = "with pin " + pinCode;
    super.rebuildInteractionSentence();
  }
}