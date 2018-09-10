import controlP5.*;
import grafica.*;
import org.gwoptics.graphics.*;
import org.gwoptics.graphics.graph2D.Graph2D;
import org.gwoptics.graphics.graph2D.LabelPos;
import org.gwoptics.graphics.graph2D.traces.Line2DTrace;
import org.gwoptics.graphics.graph2D.traces.ILine2DEquation;
import org.gwoptics.graphics.graph2D.backgrounds.*;
import processing.sound.*;

ControlP5 cp5;
Button button_openFile;
Button button_processFile;
ControlFont cf1;
String filepath;

Table table;
float[] samples_ch1;
float[] samples_ch1_d = {};
GPointsArray parray_samples_ch1;
GPointsArray parray_samples_ch1_d;

GPlot plot;

void settings() {
  size(1600, 1200); 
}

void setup() {
  
  cf1 = new ControlFont(createFont("Arial",20));
  cp5 = new ControlP5(this);
  button_openFile = cp5.addButton("openFile");
  button_openFile.setPosition(10, 10).setSize(200, 24);
  button_openFile.getCaptionLabel().setFont(cf1).setText("OpenFile");
  
  button_processFile = cp5.addButton("processFile");
  button_processFile.setPosition(10, 40).setSize(200, 24);
  button_processFile.getCaptionLabel().setFont(cf1).setText("ProcessFile");
  
  parray_samples_ch1 = new GPointsArray();
  parray_samples_ch1_d = new GPointsArray();
  plot = new GPlot(this, 100, 80, 1400, 900);
  plot.setPoints(parray_samples_ch1_d);
  
  plot.getXAxis().setAxisLabelText("Time (s)");
  plot.setXLim(00.0f, 65.0f);
  plot.setHorizontalAxesNTicks(20);
  plot.getYAxis().setAxisLabelText("uV");
  plot.setYLim(17900.0f, 18600.0f);
  plot.setTitleText("Channel 1 - Downsampled to 50Hz");
  
}


void draw() {
  //if(samples_ch1_d != null) println("samples_ch1_d is not null");
  cp5.draw();
  
  plot.defaultDraw();
}

void openFile() {
  println("open file");
  selectInput("Select a file to process", "fileSelected");
  
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    println("User selected " + selection.getAbsolutePath());
    filepath = selection.getAbsolutePath();
  }
}

void processFile() {
  println("processing file");
  table = loadTable(filepath, "header");
  println(table.getRowCount() + " total rows in table"); 
  samples_ch1 = new float[table.getRowCount()];
  int i = 0;
  for(TableRow row : table.rows()) {
    samples_ch1[i] = row.getFloat("CHANNEL1");
    i++;
  }
  samples_ch1_d = decimate(samples_ch1, 250, 5);
  println("Number of samples after decimation: " + samples_ch1_d.length);
  
  
  for(int j = 0; j < 100; j++) {
    println("Decimated sample " + j + ": " + samples_ch1_d[j]);
  }
  
  
  for(int j = 0; j < samples_ch1_d.length; j++) {
    parray_samples_ch1_d.add((float)j * 1/50, samples_ch1_d[j]);
  }
  
  for(int j = 0; j < samples_ch1.length; j++) {
    parray_samples_ch1.add((float)j * 1/50, samples_ch1[j]);
  }
  
  plot.setPoints(parray_samples_ch1_d);
}
  
float[] decimate(float sampleIn[], int samplingRate, int decimationFactor) {

  float sampleOut[] = new float[sampleIn.length / decimationFactor];
  float av;
  int fnSize = decimationFactor * 2;
  int newFs = samplingRate / decimationFactor;
  int i, j, k, m;
  float fnSizeRecpip;
  float lcoeffs[] = {0.9883188662f, 0.9703652074f, 0.9555985337,
    0.9451487175,
    0.9397460609,
    0.9397460609,
    0.9451487175,
    0.9555985337,
    0.9703652074,
    0.9883188662};
  //lcoeffs = new float[fnSize];
  
  fnSizeRecpip = 1.0 / (float) fnSize;
  
  k = 0;
  for(int l = 0; l < sampleOut.length/newFs; l++) {
    
    /*
    for (i = 0; i < fnSize; ++i) {
      lcoeffs[i] = 1;
    }
    */
    
    for (i = 0; i < samplingRate - fnSize; i += decimationFactor) {
      av = 0.0;
      for (j = 0; j < fnSize; ++j) {
        //av += sampleIn[i + j] * lcoeffs[j];
        av += sampleIn[k + i + j];
      }
      sampleOut[k] = av * fnSizeRecpip;
      ++k;
    }
    
    for (i = samplingRate - fnSize; i < samplingRate; i += decimationFactor) {
      av = 0.0;
      fnSize = samplingRate - i;
      fnSizeRecpip = 1.0 / (float) fnSize;
      
      for (j = 0; j < fnSize; ++j) {
        //av += sampleIn[i+j] * lcoeffs[j];
        av += sampleIn[k + i + j];
      }
      //sampleOut[k] = (float) av * fnSizeRecpip + (-27 *Math.cos(2.0*PI*0.5*(k/50)));
      sampleOut[k] = (float) av * fnSizeRecpip;
      ++k;
    }
  }
  
  return sampleOut;
}