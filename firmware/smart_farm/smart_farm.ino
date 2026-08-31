/*******************************************************
 * SMART FARM - ESP32 WROOM-32
 *
 * INTELLIGENT IRRIGATION SYSTEM
 *
 * PRIMARY SENSOR:
 *   Soil moisture
 *
 * SECONDARY SENSOR:
 *   DHT11 temperature + humidity
 *
 * THIRD LAYER:
 *   Weather forecast data from Firebase
 *   (published by the mobile app)
 *
 * FIREBASE DATABASE:
 *
 * /farm
 *   mode: "automatic"
 *   pump: false
 *   pumpStatus: false
 *
 *   soilMoisture: 0
 *   threshold: 1650
 *
 *   temperature: 0
 *   humidity: 0
 *
 *   irrigationDuration: 5000
 *   irrigationReason: "Waiting"
 *
 *   weather
 *       rainExpected: false
 *       rainProbability: 0
 *
 *
 * SAFETY NOTE:
 *
 *   The irrigation timer is enforced in
 *   enforceIrrigationTimeout(), which runs on
 *   EVERY loop and during WiFi reconnection.
 *
 *   It must never be moved inside an
 *   app.ready() check. If the network drops
 *   while the pump is running, that function is
 *   the only thing that will still turn it off.
 *
 *******************************************************/


// =====================================================
// 1. FIREBASE DATABASE FEATURE
// =====================================================
//
// IMPORTANT:
// This must be BEFORE #include <FirebaseClient.h>
// for newer FirebaseClient versions.
//

#define ENABLE_DATABASE


// =====================================================
// 2. LIBRARIES
// =====================================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <FirebaseClient.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <DHT.h>


// =====================================================
// 3. WIFI CONFIGURATION
// =====================================================

#define WIFI_SSID     "YOUR_WIFI_NAME"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"


// =====================================================
// 4. FIREBASE CONFIGURATION
// =====================================================

#define DATABASE_URL \
"https://smart-farm-602a3-default-rtdb.firebaseio.com"


// =====================================================
// 5. HARDWARE PINS
// =====================================================

#define DHT_PIN       26
#define RELAY_PIN     33
#define SOIL_PIN      34

#define LCD_SDA       21
#define LCD_SCL       22


// =====================================================
// 6. DHT CONFIGURATION
// =====================================================

#define DHT_TYPE DHT11

DHT dht(
  DHT_PIN,
  DHT_TYPE
);


// =====================================================
// 7. LCD CONFIGURATION
// =====================================================

#define LCD_ADDRESS 0x27

LiquidCrystal_I2C lcd(
  LCD_ADDRESS,
  16,
  2
);


// =====================================================
// 8. RELAY CONFIGURATION
// =====================================================
//
// Most relay modules are ACTIVE LOW.
//
// LOW  = ON
// HIGH = OFF
//

#define RELAY_ACTIVE_LOW true


// =====================================================
// 9. SOIL SENSOR CONFIGURATION
// =====================================================
//
// Current assumption:
//
// Higher ADC value = drier soil
//
// soil > threshold
//      = DRY
//
// soil <= threshold
//      = WET
//
// If your sensor behaves opposite,
// change this to false.
//

#define SOIL_DRY_WHEN_HIGH true


// =====================================================
// 10. WEATHER CONFIGURATION
// =====================================================
//
// If rain is expected AND probability is at or above
// this value, automatic irrigation will be delayed.
//
// The mobile app applies this same cut-off when it
// decides what to publish. If you change this number,
// change RainForecaster.minConfidence in the app to
// match, or the app will explain one thing while the
// pump does another.
//

#define RAIN_PROBABILITY_LIMIT 60


// =====================================================
// 11. FIREBASE OBJECTS
// =====================================================
//
// NEW FirebaseClient API:
//
// DefaultNetwork has been removed.
// getNetwork() has been removed.
//
// The AsyncClient now receives the SSL client directly.
//

WiFiClientSecure sslClient;

using AsyncClient = AsyncClientClass;

AsyncClient firebaseClient(
  sslClient
);

FirebaseApp app;

RealtimeDatabase Database;

NoAuth noAuth;


// =====================================================
// 12. SYSTEM VARIABLES
// =====================================================

// Operating mode
String currentMode = "automatic";

// Manual pump command
bool manualPumpCommand = false;

// Actual pump state
bool pumpStatus = false;


// -----------------------------------------------------
// Soil
// -----------------------------------------------------

int soilMoisture = 0;

int threshold = 1650;


// -----------------------------------------------------
// DHT11
// -----------------------------------------------------

float temperature = 0.0;

float humidity = 0.0;


// -----------------------------------------------------
// Weather
// -----------------------------------------------------

bool rainExpected = false;

int rainProbability = 0;


// =====================================================
// 13. IRRIGATION VARIABLES
// =====================================================

// How long pump should run
unsigned long irrigationDuration = 5000;

// Time irrigation started
unsigned long irrigationStartTime = 0;

// Time previous irrigation ended
unsigned long lastIrrigationTime = 0;

// Minimum time between irrigation cycles
const unsigned long IRRIGATION_COOLDOWN = 30000;

// Is irrigation currently running?
bool irrigationRunning = false;

// Explanation of current irrigation state
String irrigationReason = "Waiting";


// -----------------------------------------------------
// ABSOLUTE PUMP RUNTIME CEILING
// -----------------------------------------------------
//
// A last line of defence.
//
// If irrigationDuration is ever corrupted by a bad
// Firebase value or a variable overflow, this ceiling
// still stops the pump.
//
// Set well above the longest normal cycle (10 s) but
// far below the point where a field would flood.
//

const unsigned long MAX_PUMP_RUNTIME = 120000;


// =====================================================
// 14. TIMERS
// =====================================================

unsigned long lastFirebaseRead = 0;

unsigned long lastSensorRead = 0;

unsigned long lastFirebaseUpload = 0;

unsigned long lastLCDUpdate = 0;

unsigned long lastWiFiCheck = 0;


// =====================================================
// 15. INTERVALS
// =====================================================

const unsigned long FIREBASE_READ_INTERVAL = 3000;

const unsigned long SENSOR_INTERVAL = 3000;

const unsigned long FIREBASE_UPLOAD_INTERVAL = 5000;

const unsigned long LCD_SCREEN_INTERVAL = 3000;


// =====================================================
// 16. LCD SCREEN
// =====================================================

int lcdScreen = 0;


// =====================================================
// 17. FORWARD DECLARATIONS
// =====================================================
//
// enforceIrrigationTimeout() is called from
// connectWiFi(), which is defined before it.
//
// The Arduino IDE generates prototypes
// automatically, but declaring them explicitly
// keeps this sketch compiling under PlatformIO
// and plain arduino-cli too.
//

void setPump(bool state);

void stopIrrigation();

void enforceIrrigationTimeout();


// =====================================================
// 18. SET PUMP
// =====================================================

void setPump(bool state)
{
  pumpStatus = state;


  if (RELAY_ACTIVE_LOW)
  {
    digitalWrite(
      RELAY_PIN,
      state ? LOW : HIGH
    );
  }
  else
  {
    digitalWrite(
      RELAY_PIN,
      state ? HIGH : LOW
    );
  }


  Serial.print("PUMP: ");


  if (state)
  {
    Serial.println("ON");
  }
  else
  {
    Serial.println("OFF");
  }
}


// =====================================================
// 19. WIFI CONNECTION
// =====================================================

void connectWiFi()
{
  if (
    WiFi.status() ==
    WL_CONNECTED
  )
  {
    return;
  }


  Serial.println();

  Serial.println(
    "Connecting to WiFi..."
  );


  WiFi.begin(
    WIFI_SSID,
    WIFI_PASSWORD
  );


  unsigned long startTime =
    millis();


  while (
    WiFi.status() != WL_CONNECTED &&
    millis() - startTime < 20000
  )
  {
    // ---------------------------------------------
    // SAFETY
    //
    // This loop can block for up to 20 seconds,
    // which is longer than an entire irrigation
    // cycle (4-10 s).
    //
    // Without this call, losing WiFi mid-cycle
    // would hold the pump on for the whole
    // reconnection attempt.
    // ---------------------------------------------

    enforceIrrigationTimeout();


    Serial.print(".");

    delay(500);
  }


  Serial.println();


  if (
    WiFi.status() ==
    WL_CONNECTED
  )
  {
    Serial.println(
      "WiFi connected!"
    );


    Serial.print(
      "IP Address: "
    );


    Serial.println(
      WiFi.localIP()
    );
  }
  else
  {
    Serial.println(
      "WiFi connection failed."
    );
  }
}


// =====================================================
// 20. FIREBASE INITIALIZATION
// =====================================================

void setupFirebase()
{
  Serial.println();

  Serial.println(
    "Initializing Firebase..."
  );


  // Skip SSL certificate verification.
  // Suitable for this prototype.
  //
  // For production, certificate verification
  // should be configured properly.

  sslClient.setInsecure();


  // Initialize Firebase.

  initializeApp(
    firebaseClient,
    app,
    getAuth(noAuth)
  );


  // Connect FirebaseApp to Realtime Database.

  app.getApp<RealtimeDatabase>(
    Database
  );


  // Set database URL.

  Database.url(
    DATABASE_URL
  );


  Serial.println(
    "Firebase initialized."
  );
}


// =====================================================
// 21. READ MODE
// =====================================================

void readMode()
{
  if (!app.ready())
  {
    return;
  }


  String value =
    Database.get<String>(
      firebaseClient,
      "/farm/mode"
    );


  if (
    firebaseClient.lastError().code() == 0
  )
  {
    value.toLowerCase();


    if (
      value == "automatic" ||
      value == "manual"
    )
    {
      currentMode =
        value;


      Serial.print(
        "Mode: "
      );


      Serial.println(
        currentMode
      );
    }
    else
    {
      Serial.print(
        "Invalid mode: "
      );


      Serial.println(
        value
      );
    }
  }
  else
  {
    Serial.print(
      "Failed to read mode: "
    );


    Serial.println(
      firebaseClient.lastError().message()
    );
  }
}


// =====================================================
// 22. READ MANUAL PUMP COMMAND
// =====================================================

void readPumpCommand()
{
  if (!app.ready())
  {
    return;
  }


  bool value =
    Database.get<bool>(
      firebaseClient,
      "/farm/pump"
    );


  if (
    firebaseClient.lastError().code() == 0
  )
  {
    manualPumpCommand =
      value;


    Serial.print(
      "Manual Pump Command: "
    );


    Serial.println(
      manualPumpCommand
      ? "ON"
      : "OFF"
    );
  }
  else
  {
    Serial.print(
      "Failed to read pump command: "
    );


    Serial.println(
      firebaseClient.lastError().message()
    );
  }
}


// =====================================================
// 23. READ SOIL THRESHOLD
// =====================================================

void readThreshold()
{
  if (!app.ready())
  {
    return;
  }


  int value =
    Database.get<int>(
      firebaseClient,
      "/farm/threshold"
    );


  if (
    firebaseClient.lastError().code() == 0
  )
  {
    if (
      value > 0 &&
      value < 4096
    )
    {
      threshold =
        value;
    }


    Serial.print(
      "Threshold: "
    );


    Serial.println(
      threshold
    );
  }
  else
  {
    Serial.print(
      "Failed to read threshold: "
    );


    Serial.println(
      firebaseClient.lastError().message()
    );
  }
}


// =====================================================
// 24. READ WEATHER
// =====================================================
//
// These two values are written by the mobile app,
// not by this device. The ESP32 has no route to a
// weather service.
//
// If the app is never run, rainExpected stays false
// and irrigation proceeds on soil and air readings
// alone. That is the intended fallback.
//

void readWeather()
{
  if (!app.ready())
  {
    return;
  }


  // -----------------------------------------
  // Rain expected
  // -----------------------------------------

  bool newRainExpected =
    Database.get<bool>(
      firebaseClient,
      "/farm/weather/rainExpected"
    );


  if (
    firebaseClient.lastError().code() == 0
  )
  {
    rainExpected =
      newRainExpected;
  }


  // -----------------------------------------
  // Rain probability
  // -----------------------------------------

  int newProbability =
    Database.get<int>(
      firebaseClient,
      "/farm/weather/rainProbability"
    );


  if (
    firebaseClient.lastError().code() == 0
  )
  {
    if (
      newProbability >= 0 &&
      newProbability <= 100
    )
    {
      rainProbability =
        newProbability;
    }
  }


  Serial.print(
    "Rain expected: "
  );


  Serial.println(
    rainExpected
    ? "YES"
    : "NO"
  );


  Serial.print(
    "Rain probability: "
  );


  Serial.print(
    rainProbability
  );


  Serial.println("%");
}


// =====================================================
// 25. READ SOIL MOISTURE
// =====================================================

void readSoilMoisture()
{
  long total = 0;

  const int samples = 10;


  for (
    int i = 0;
    i < samples;
    i++
  )
  {
    total +=
      analogRead(SOIL_PIN);

    delay(5);
  }


  soilMoisture =
    total / samples;


  Serial.print(
    "Soil Moisture: "
  );


  Serial.println(
    soilMoisture
  );
}


// =====================================================
// 26. READ DHT11
// =====================================================

void readDHT()
{
  float newHumidity =
    dht.readHumidity();


  float newTemperature =
    dht.readTemperature();


  if (
    !isnan(newHumidity) &&
    !isnan(newTemperature)
  )
  {
    humidity =
      newHumidity;


    temperature =
      newTemperature;


    Serial.print(
      "Temperature: "
    );


    Serial.print(
      temperature
    );


    Serial.println(
      " C"
    );


    Serial.print(
      "Humidity: "
    );


    Serial.print(
      humidity
    );


    Serial.println(
      " %"
    );
  }
  else
  {
    Serial.println(
      "DHT11 reading failed."
    );
  }
}


// =====================================================
// 27. DETERMINE IF SOIL IS DRY
// =====================================================

bool isSoilDry()
{
  if (
    SOIL_DRY_WHEN_HIGH
  )
  {
    return soilMoisture >
           threshold;
  }
  else
  {
    return soilMoisture <
           threshold;
  }
}


// =====================================================
// 28. CALCULATE IRRIGATION DURATION
// =====================================================
//
// Soil moisture determines WHETHER to irrigate.
//
// DHT11 determines HOW LONG to irrigate.
//

unsigned long calculateIrrigationDuration()
{
  unsigned long duration;


  // -----------------------------------------
  // Very hot + dry
  // -----------------------------------------

  if (
    temperature >= 32 &&
    humidity < 50
  )
  {
    duration =
      10000;


    irrigationReason =
      "Hot/Dry";
  }


  // -----------------------------------------
  // Hot
  // -----------------------------------------

  else if (
    temperature >= 30 &&
    humidity < 60
  )
  {
    duration =
      8000;


    irrigationReason =
      "Hot";
  }


  // -----------------------------------------
  // Normal
  // -----------------------------------------

  else if (
    temperature >= 25 &&
    humidity < 70
  )
  {
    duration =
      6000;


    irrigationReason =
      "Normal";
  }


  // -----------------------------------------
  // Cool + humid
  // -----------------------------------------

  else
  {
    duration =
      4000;


    irrigationReason =
      "Cool/Humid";
  }


  return duration;
}


// =====================================================
// 29. CHECK WEATHER
// =====================================================

bool shouldDelayForRain()
{
  if (
    rainExpected &&
    rainProbability >=
    RAIN_PROBABILITY_LIMIT
  )
  {
    return true;
  }


  return false;
}


// =====================================================
// 30. START IRRIGATION
// =====================================================

void startIrrigation()
{
  if (irrigationRunning)
  {
    return;
  }


  // -----------------------------------------
  // Check weather
  // -----------------------------------------

  if (
    shouldDelayForRain()
  )
  {
    setPump(false);


    irrigationReason =
      "Rain Expected";


    Serial.println(
      "Irrigation delayed."
    );


    Serial.println(
      "Rain is expected."
    );


    return;
  }


  // -----------------------------------------
  // Calculate duration
  // -----------------------------------------

  irrigationDuration =
    calculateIrrigationDuration();


  // -----------------------------------------
  // Clamp the duration
  // -----------------------------------------
  //
  // enforceIrrigationTimeout() trusts this
  // value, so it must be sane before the pump
  // is allowed to start.
  //

  if (
    irrigationDuration == 0 ||
    irrigationDuration > MAX_PUMP_RUNTIME
  )
  {
    Serial.print(
      "Suspicious duration: "
    );


    Serial.println(
      irrigationDuration
    );


    irrigationDuration =
      5000;
  }


  // -----------------------------------------
  // Start irrigation
  // -----------------------------------------
  //
  // The start time is recorded BEFORE the pump
  // is energised, so the timer can never be
  // shorter than the actual runtime.
  //

  irrigationStartTime =
    millis();


  irrigationRunning =
    true;


  setPump(true);


  Serial.println();

  Serial.println(
    "=========================="
  );


  Serial.println(
    "IRRIGATION STARTED"
  );


  Serial.print(
    "Duration: "
  );


  Serial.print(
    irrigationDuration
  );


  Serial.println(
    " ms"
  );


  Serial.print(
    "Reason: "
  );


  Serial.println(
    irrigationReason
  );


  Serial.println(
    "=========================="
  );
}


// =====================================================
// 31. STOP IRRIGATION
// =====================================================

void stopIrrigation()
{
  setPump(false);


  irrigationRunning =
    false;


  lastIrrigationTime =
    millis();


  irrigationReason =
    "Irrigation Done";


  Serial.println();

  Serial.println(
    "IRRIGATION STOPPED"
  );
}


// =====================================================
// 32. ENFORCE IRRIGATION TIMEOUT
// =====================================================
//
// THIS IS A SAFETY FUNCTION.
//
// It is the only thing that stops an automatic
// irrigation cycle, and it deliberately depends on
// NOTHING except millis() and the relay pin.
//
// No WiFi.
// No Firebase.
// No app.ready().
//
// Rules for editing:
//
//   1. Never move this inside an app.ready()
//      check or any network-conditional block.
//
//   2. Never add a network call to it.
//
//   3. Call it from any loop that can block for
//      longer than a moment.
//
// millis() overflows roughly every 49 days. The
// unsigned subtraction below stays correct across
// that rollover, which is why it is written as
// (now - start) rather than (start + duration).
//

void enforceIrrigationTimeout()
{
  if (!irrigationRunning)
  {
    return;
  }


  unsigned long elapsed =
    millis() - irrigationStartTime;


  // -----------------------------------------
  // Normal completion
  // -----------------------------------------

  if (
    elapsed >= irrigationDuration
  )
  {
    Serial.println();

    Serial.println(
      "Irrigation time reached."
    );


    stopIrrigation();

    return;
  }


  // -----------------------------------------
  // Absolute ceiling
  // -----------------------------------------
  //
  // Reached only if irrigationDuration has been
  // corrupted despite the clamp in
  // startIrrigation().
  //

  if (
    elapsed >= MAX_PUMP_RUNTIME
  )
  {
    Serial.println();

    Serial.println(
      "!! MAX PUMP RUNTIME EXCEEDED !!"
    );


    Serial.println(
      "Forcing pump off."
    );


    stopIrrigation();


    irrigationReason =
      "Safety Stop";
  }
}


// =====================================================
// 33. MANAGE AUTOMATIC IRRIGATION
// =====================================================

void manageIrrigation()
{
  // -----------------------------------------
  // If a cycle is already running
  // -----------------------------------------
  //
  // Stopping it is NOT handled here.
  //
  // enforceIrrigationTimeout() owns that, and it
  // runs every loop whether or not Firebase is
  // reachable. Duplicating the check here would
  // suggest this path is what protects the pump,
  // and it is not.
  //

  if (irrigationRunning)
  {
    return;
  }


  // -----------------------------------------
  // Soil is primary decision
  // -----------------------------------------

  if (!isSoilDry())
  {
    setPump(false);


    irrigationReason =
      "Soil Wet";


    return;
  }


  // -----------------------------------------
  // Cooldown
  // -----------------------------------------

  if (
    millis() -
    lastIrrigationTime <
    IRRIGATION_COOLDOWN
  )
  {
    irrigationReason =
      "Cooldown";


    return;
  }


  // -----------------------------------------
  // Soil is dry
  // -----------------------------------------

  Serial.println();

  Serial.println(
    "Soil is DRY."
  );


  Serial.println(
    "Checking irrigation strategy..."
  );


  startIrrigation();
}


// =====================================================
// 34. MANUAL MODE
// =====================================================

void manualMode()
{
  // Automatic cycle is cancelled when
  // switching to manual mode.

  irrigationRunning =
    false;


  if (
    manualPumpCommand
  )
  {
    irrigationReason =
      "Manual ON";


    setPump(true);
  }
  else
  {
    irrigationReason =
      "Manual OFF";


    setPump(false);
  }
}


// =====================================================
// 35. UPLOAD SOIL MOISTURE
// =====================================================

void uploadSoilMoisture()
{
  if (!app.ready())
  {
    return;
  }


  Database.set<int>(
    firebaseClient,
    "/farm/soilMoisture",
    soilMoisture
  );


  if (
    firebaseClient.lastError().code() != 0
  )
  {
    Serial.print(
      "Soil upload failed: "
    );


    Serial.println(
      firebaseClient.lastError().message()
    );
  }
}


// =====================================================
// 36. UPLOAD PUMP STATUS
// =====================================================
//
// This is the value the mobile app treats as the
// pump's actual state. It must always reflect the
// relay, never a pending command.
//

void uploadPumpStatus()
{
  if (!app.ready())
  {
    return;
  }


  Database.set<bool>(
    firebaseClient,
    "/farm/pumpStatus",
    pumpStatus
  );
}


// =====================================================
// 37. UPLOAD TEMPERATURE
// =====================================================

void uploadTemperature()
{
  if (!app.ready())
  {
    return;
  }


  Database.set<float>(
    firebaseClient,
    "/farm/temperature",
    temperature
  );
}


// =====================================================
// 38. UPLOAD HUMIDITY
// =====================================================

void uploadHumidity()
{
  if (!app.ready())
  {
    return;
  }


  Database.set<float>(
    firebaseClient,
    "/farm/humidity",
    humidity
  );
}


// =====================================================
// 39. UPLOAD IRRIGATION DURATION
// =====================================================

void uploadIrrigationDuration()
{
  if (!app.ready())
  {
    return;
  }


  Database.set<int>(
    firebaseClient,
    "/farm/irrigationDuration",
    (int)irrigationDuration
  );
}


// =====================================================
// 40. UPLOAD IRRIGATION REASON
// =====================================================

void uploadIrrigationReason()
{
  if (!app.ready())
  {
    return;
  }


  Database.set<String>(
    firebaseClient,
    "/farm/irrigationReason",
    irrigationReason
  );
}


// =====================================================
// 41. LCD SCREEN 1
// =====================================================

void lcdScreen1()
{
  lcd.clear();


  lcd.setCursor(
    0,
    0
  );


  lcd.print(
    "SMART FARM"
  );


  lcd.setCursor(
    0,
    1
  );


  lcd.print(
    "Mode: "
  );


  if (
    currentMode ==
    "automatic"
  )
  {
    lcd.print(
      "AUTO"
    );
  }
  else
  {
    lcd.print(
      "MANUAL"
    );
  }
}


// =====================================================
// 42. LCD SCREEN 2
// =====================================================

void lcdScreen2()
{
  lcd.clear();


  lcd.setCursor(
    0,
    0
  );


  lcd.print(
    "Soil: "
  );


  lcd.print(
    soilMoisture
  );


  lcd.setCursor(
    0,
    1
  );


  lcd.print(
    "Pump: "
  );


  if (pumpStatus)
  {
    lcd.print(
      "ON"
    );
  }
  else
  {
    lcd.print(
      "OFF"
    );
  }
}


// =====================================================
// 43. LCD SCREEN 3
// =====================================================

void lcdScreen3()
{
  lcd.clear();


  lcd.setCursor(
    0,
    0
  );


  lcd.print(
    "Temp: "
  );


  lcd.print(
    temperature,
    1
  );


  lcd.print(
    " C"
  );


  lcd.setCursor(
    0,
    1
  );


  lcd.print(
    "Hum: "
  );


  lcd.print(
    humidity,
    0
  );


  lcd.print(
    "%"
  );
}


// =====================================================
// 44. LCD SCREEN 4
// =====================================================

void lcdScreen4()
{
  lcd.clear();


  lcd.setCursor(
    0,
    0
  );


  if (
    isSoilDry()
  )
  {
    lcd.print(
      "Soil: DRY"
    );
  }
  else
  {
    lcd.print(
      "Soil: WET"
    );
  }


  lcd.setCursor(
    0,
    1
  );


  if (
    rainExpected
  )
  {
    lcd.print(
      "Rain:"
    );


    lcd.print(
      rainProbability
    );


    lcd.print(
      "%"
    );
  }
  else
  {
    lcd.print(
      "Rain: NO"
    );
  }
}


// =====================================================
// 45. LCD SCREEN 5
// =====================================================

void lcdScreen5()
{
  lcd.clear();


  lcd.setCursor(
    0,
    0
  );


  lcd.print(
    "Strategy:"
  );


  lcd.setCursor(
    0,
    1
  );


  if (
    irrigationReason ==
    "Hot/Dry"
  )
  {
    lcd.print(
      "HOT/DRY"
    );
  }


  else if (
    irrigationReason ==
    "Hot"
  )
  {
    lcd.print(
      "HOT"
    );
  }


  else if (
    irrigationReason ==
    "Normal"
  )
  {
    lcd.print(
      "NORMAL"
    );
  }


  else if (
    irrigationReason ==
    "Cool/Humid"
  )
  {
    lcd.print(
      "COOL/HUMID"
    );
  }


  else if (
    irrigationReason ==
    "Rain Expected"
  )
  {
    lcd.print(
      "RAIN DELAY"
    );
  }


  else if (
    irrigationReason ==
    "Safety Stop"
  )
  {
    lcd.print(
      "SAFETY STOP"
    );
  }


  else
  {
    lcd.print(
      irrigationReason
    );
  }
}


// =====================================================
// 46. UPDATE LCD
// =====================================================

void updateLCD()
{
  if (
    millis() -
    lastLCDUpdate <
    LCD_SCREEN_INTERVAL
  )
  {
    return;
  }


  lastLCDUpdate =
    millis();


  switch (lcdScreen)
  {
    case 0:
      lcdScreen1();
      break;


    case 1:
      lcdScreen2();
      break;


    case 2:
      lcdScreen3();
      break;


    case 3:
      lcdScreen4();
      break;


    case 4:
      lcdScreen5();
      break;
  }


  lcdScreen++;


  if (
    lcdScreen > 4
  )
  {
    lcdScreen = 0;
  }
}


// =====================================================
// 47. SETUP
// =====================================================

void setup()
{
  Serial.begin(
    115200
  );


  delay(1000);


  Serial.println();

  Serial.println(
    "=========================="
  );


  Serial.println(
    "      SMART FARM"
  );


  Serial.println(
    "=========================="
  );


  // ===================================================
  // RELAY
  // ===================================================
  //
  // The relay is driven to OFF before the pin is
  // set to OUTPUT, so a floating pin during boot
  // cannot pulse the pump.
  //

  if (
    RELAY_ACTIVE_LOW
  )
  {
    digitalWrite(
      RELAY_PIN,
      HIGH
    );
  }
  else
  {
    digitalWrite(
      RELAY_PIN,
      LOW
    );
  }


  pinMode(
    RELAY_PIN,
    OUTPUT
  );


  // Re-assert after the pin is an output.

  if (
    RELAY_ACTIVE_LOW
  )
  {
    digitalWrite(
      RELAY_PIN,
      HIGH
    );
  }
  else
  {
    digitalWrite(
      RELAY_PIN,
      LOW
    );
  }


  pumpStatus =
    false;


  irrigationRunning =
    false;


  // ===================================================
  // SOIL SENSOR
  // ===================================================

  pinMode(
    SOIL_PIN,
    INPUT
  );


  // ===================================================
  // DHT11
  // ===================================================

  dht.begin();


  // ===================================================
  // LCD
  // ===================================================

  Wire.begin(
    LCD_SDA,
    LCD_SCL
  );


  lcd.init();

  lcd.backlight();

  lcd.clear();


  lcd.setCursor(
    0,
    0
  );


  lcd.print(
    "SMART FARM"
  );


  lcd.setCursor(
    0,
    1
  );


  lcd.print(
    "Starting..."
  );


  // ===================================================
  // WIFI
  // ===================================================

  connectWiFi();


  // ===================================================
  // FIREBASE
  // ===================================================

  if (
    WiFi.status() ==
    WL_CONNECTED
  )
  {
    setupFirebase();
  }


  delay(2000);


  lcd.clear();


  Serial.println();

  Serial.println(
    "SMART FARM READY"
  );
}


// =====================================================
// 48. MAIN LOOP
// =====================================================

void loop()
{
  // ===================================================
  // SAFETY FIRST
  // ===================================================
  //
  // This runs before anything that can fail,
  // block, or depend on the network.
  //
  // If Firebase is unreachable, everything below
  // this point may be skipped. A running pump
  // still gets turned off.
  //

  enforceIrrigationTimeout();


  // ===================================================
  // FIREBASE
  // ===================================================

  app.loop();


  // ===================================================
  // WIFI CHECK
  // ===================================================

  if (
    millis() -
    lastWiFiCheck >=
    10000
  )
  {
    lastWiFiCheck =
      millis();


    if (
      WiFi.status() !=
      WL_CONNECTED
    )
    {
      Serial.println(
        "WiFi disconnected."
      );


      connectWiFi();
    }
  }


  // ===================================================
  // SENSOR READINGS
  // ===================================================
  //
  // Deliberately outside the Firebase block:
  // the LCD must keep showing live readings even
  // with no network.
  //

  if (
    millis() -
    lastSensorRead >=
    SENSOR_INTERVAL
  )
  {
    lastSensorRead =
      millis();


    // PRIMARY SENSOR
    readSoilMoisture();


    // SECONDARY SENSOR
    readDHT();
  }


  // ===================================================
  // FIREBASE READ
  // ===================================================

  if (
    millis() -
    lastFirebaseRead >=
    FIREBASE_READ_INTERVAL
  )
  {
    lastFirebaseRead =
      millis();


    if (
      app.ready()
    )
    {
      // -----------------------------------------------
      // Operating mode
      // -----------------------------------------------

      readMode();


      // -----------------------------------------------
      // Manual pump command
      // -----------------------------------------------

      readPumpCommand();


      // -----------------------------------------------
      // Soil threshold
      // -----------------------------------------------

      readThreshold();


      // -----------------------------------------------
      // Weather
      // -----------------------------------------------

      readWeather();


      // -----------------------------------------------
      // AUTOMATIC MODE
      // -----------------------------------------------
      //
      // This decides whether to START a cycle.
      // Stopping one is handled unconditionally
      // at the top of loop().
      // -----------------------------------------------

      if (
        currentMode ==
        "automatic"
      )
      {
        Serial.println();

        Serial.println(
          "AUTOMATIC MODE"
        );


        manageIrrigation();
      }


      // -----------------------------------------------
      // MANUAL MODE
      // -----------------------------------------------

      else if (
        currentMode ==
        "manual"
      )
      {
        Serial.println();

        Serial.println(
          "MANUAL MODE"
        );


        manualMode();
      }
    }
  }


  // ===================================================
  // FIREBASE UPLOAD
  // ===================================================

  if (
    millis() -
    lastFirebaseUpload >=
    FIREBASE_UPLOAD_INTERVAL
  )
  {
    lastFirebaseUpload =
      millis();


    if (
      app.ready()
    )
    {
      uploadSoilMoisture();

      uploadPumpStatus();

      uploadTemperature();

      uploadHumidity();

      uploadIrrigationDuration();

      uploadIrrigationReason();
    }
  }


  // ===================================================
  // LCD
  // ===================================================

  updateLCD();


  // ===================================================
  // SMALL DELAY
  // ===================================================

  delay(10);
}
