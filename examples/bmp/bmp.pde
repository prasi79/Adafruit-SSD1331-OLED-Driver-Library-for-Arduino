/*************************************************** 
  This is a example sketch demonstrating bitmap drawing
  capabilities of the SSD1331 library  for the 0.96" 
  16-bit Color OLED with SSD1331 driver chip

  Pick one up today in the adafruit shop!
  ------> http://www.adafruit.com/products/684

  These displays use SPI to communicate, 4 or 5 pins are required to  
  interface
  Adafruit invests time and resources providing this open source code, 
  please support Adafruit and open-source hardware by purchasing 
  products from Adafruit!

  Written by Limor Fried/Ladyada for Adafruit Industries.  
  BSD license, all text above must be included in any redistribution
 ****************************************************/

#include <Adafruit_SSD1331.h>
#include <SD.h>
#include <SPI.h>


// If we are using the hardware SPI interface, these are the pins (for future ref)
#define sclk 13
#define mosi 11
#define cs   10
#define rst  9
#define dc   8

// Color definitions
#define	BLACK           0x0000
#define	BLUE            0x001F
#define	RED             0xF800
#define	GREEN           0x07E0
#define CYAN            0x07FF
#define MAGENTA         0xF81F
#define YELLOW          0xFFE0  
#define WHITE           0xFFFF

// to draw images from the SD card, we will share the hardware SPI interface
Adafruit_SSD1331 tft = Adafruit_SSD1331(cs, dc, rst);  

// For Arduino Uno/Duemilanove, etc
//  connect the SD card with MOSI going to pin 11, MISO going to pin 12 and SCK going to pin 13 (standard)
//  Then pin 4 goes to CS (or whatever you have set up)
#define SD_CS 4    // Set the chip select line to whatever you use (4 doesnt conflict with the library)

// the file itself
File bmpFile;

// information we extract about the bitmap file
int bmpWidth, bmpHeight;
uint8_t bmpDepth, bmpImageoffset;


void testtext(uint16_t color) {
  tft.fillScreen(BLACK);
  tft.setCursor(0, 20);
  tft.setTextColor(color);
  tft.setTextSize(1);
  tft.println("Hello World!");
  tft.setTextSize(1);
  tft.println(1234.56);
  tft.setTextSize(1);
  tft.println(0xDEADBEEF, HEX);
}

void setup(void) {
  Serial.begin(9600);
   
  pinMode(cs, OUTPUT);
  digitalWrite(cs, HIGH);
     
  // initialize a ST7735R TFT
  tft.initDisplay();

  Serial.println("init");
  
  tft.fillScreen(BLUE);
  
  delay(500);
  Serial.print("Initializing SD card...");

  if (!SD.begin(SD_CS)) {
    Serial.println("failed!");
    return;
  }
  Serial.println("SD OK!");

  bmpFile = SD.open("violet.bmp");
  
  if (! bmpFile) {
    Serial.println("didnt find image");
    while (1);
  }

  tft.println("Found BMP");
  
  if (! bmpReadHeader(bmpFile)) { 
     Serial.println("bad bmp");
     return;
  }
  
  Serial.print("image size "); 
  Serial.print(bmpWidth, DEC);
  Serial.print(", ");
  Serial.println(bmpHeight, DEC);
  
    // Just do a simple test
  tft.fillScreen(BLACK);
  

  bmpdraw(bmpFile, 0, 0);
}

void loop() {
}


void testfastlines(uint16_t color1, uint16_t color2) {
   tft.fillScreen(BLACK);
   for (uint16_t y=0; y < tft.height(); y+=5) {
     tft.drawHorizontalLine(0, y, tft.width(), color1);
   }
   for (uint16_t x=0; x < tft.width(); x+=5) {
     tft.drawVerticalLine(x, 0, tft.height(), color2);
   }
}

/*********************************************/
// This procedure reads a bitmap and draws it to the screen
// its sped up by reading many pixels worth of data at a time
// instead of just one pixel at a time. increading the buffer takes
// more RAM but makes the drawing a little faster. 20 pixels' worth
// is probably a good place

#define BUFFPIXEL 1

void bmpdraw(File f, int x, int y) {
  bmpFile.seek(bmpImageoffset);
  
  uint32_t time = millis();
  uint16_t p; 
  uint8_t g, b;
  int i, j;
  
  uint8_t sdbuffer[3 * BUFFPIXEL];  // 3 * pixels to buffer
  uint8_t buffidx = 3*BUFFPIXEL;

  
  for (i=0; i< bmpHeight; i++) {
    // bitmaps are stored with the BOTTOM line first so we have to move 'up'
  
    for (j=0; j<bmpWidth; j++) {
      // read more pixels
      if (buffidx >= 3*BUFFPIXEL) {
        bmpFile.read(sdbuffer, 3*BUFFPIXEL);
        buffidx = 0;
      }
      
      // convert pixel from 888 to 565
      b = sdbuffer[buffidx++];     // blue
      g = sdbuffer[buffidx++];     // green
      p = sdbuffer[buffidx++];     // red
      
      p >>= 3;
      p <<= 6;
      
      g >>= 2;
      p |= g;
      p <<= 5;
      
      b >>= 3;
      p |= b;
     //Serial.print(p, HEX);
      // write out the 16 bits of color
   // Serial.print("x: "); Serial.print(i); Serial.print(", y:"); Serial.println(j);
     tft.drawPixel(j, bmpHeight-i, p);
    //  tft.pushColor(p);
    //  tft.fillScreen(RED);

    }
  }
  Serial.print(millis() - time, DEC);
  Serial.println(" ms");
}

boolean bmpReadHeader(File f) {
   // read header
  uint32_t tmp;
  
  if (read16(f) != 0x4D42) {
    // magic bytes missing
    return false;
  }
 
  // read file size
  tmp = read32(f);  
  Serial.print("size 0x"); Serial.println(tmp, HEX);
  
  // read and ignore creator bytes
  read32(f);
  
  bmpImageoffset = read32(f);  
  Serial.print("offset "); Serial.println(bmpImageoffset, DEC);
  
  // read DIB header
  tmp = read32(f);
  Serial.print("header size "); Serial.println(tmp, DEC);
  bmpWidth = read32(f);
  bmpHeight = read32(f);

  
  if (read16(f) != 1)
    return false;
    
  bmpDepth = read16(f);
  Serial.print("bitdepth "); Serial.println(bmpDepth, DEC);

  if (read32(f) != 0) {
    // compression not supported!
    return false;
  }
  
  Serial.print("compression "); Serial.println(tmp, DEC);

  return true;
}

/*********************************************/

// These read data from the SD card file and convert them to big endian 
// (the data is stored in little endian format!)

// LITTLE ENDIAN!
uint16_t read16(File f) {
  uint16_t d;
  uint8_t b;
  b = f.read();
  d = f.read();
  d <<= 8;
  d |= b;
  return d;
}


// LITTLE ENDIAN!
uint32_t read32(File f) {
  uint32_t d;
  uint16_t b;
 
  b = read16(f);
  d = read16(f);
  d <<= 16;
  d |= b;
  return d;
}

