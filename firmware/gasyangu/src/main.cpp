#include <Arduino.h>
#include "HX711.h"
#include <LiquidCrystal_I2C.h>
#include "esp_sleep.h"
#include "driver/gpio.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ── Pin definitions ────────────────────────────────────────────────────────
const int        LOADCELL_DOUT_PIN  = 18;
const int        LOADCELL_SCK_PIN   = 19;
const gpio_num_t WAKEUP_CONFIG_PIN  = GPIO_NUM_5;

// ── Sleep / publish interval ───────────────────────────────────────────────
// Device sleeps for SLEEP_DURATION_US, then wakes and publishes weight for
// ACTIVE_WINDOW_MS before sleeping again. GPIO5 button press also wakes it.
#define SLEEP_DURATION_US  (5ULL * 60ULL * 1000000ULL)   // 1 min sleep
#define ACTIVE_WINDOW_MS   30000UL                         // 30 s awake window
#define PUBLISH_INTERVAL_MS 2000UL                         // publish every 2 s

// ── HX711 calibration ─────────────────────────────────────────────────────
const int   CALIBRATION_VALUE  = -150278;
const float calibration_factor = CALIBRATION_VALUE / 450.0f;

// ── BLE UUIDs ─────────────────────────────────────────────────────────────
#define GASYANGU_SERVICE_UUID  "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define WEIGHT_CHAR_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ── Peripherals ───────────────────────────────────────────────────────────
// Change 0x27 to 0x3F if the display does not respond.
LiquidCrystal_I2C lcd(0x27, 16, 2);
HX711             scale;

// ── BLE state ─────────────────────────────────────────────────────────────
BLEServer         *pServer     = nullptr;
BLECharacteristic *pWeightChar = nullptr;
bool               bleConnected = false;

// ── Active-window tracking ─────────────────────────────────────────────────
// Stamped at boot and after each wakeup; loop() publishes until this expires.
static unsigned long _wakeMillis = 0;

// ── CGRAM slot 0 – gas flame icon ─────────────────────────────────────────
byte flame[8] = {
  0b00100,
  0b01110,
  0b01110,
  0b11111,
  0b11111,
  0b11011,
  0b01110,
  0b00000
};

// ── BLE connection callbacks ───────────────────────────────────────────────
class GasYanguServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *) override {
    bleConnected = true;
  }
  void onDisconnect(BLEServer *) override {
    bleConnected = false;
    BLEDevice::startAdvertising();   // re-advertise so the app can reconnect
  }
};

// ── Helpers ───────────────────────────────────────────────────────────────
static void typewrite(uint8_t col, uint8_t row, const char *text, int ms = 55)
{
  lcd.setCursor(col, row);
  for (int i = 0; text[i]; i++) {
    lcd.print(text[i]);
    delay(ms);
  }
}

// ── BLE publish ───────────────────────────────────────────────────────────
// Sends weight (kg) as a plain ASCII string, e.g. "12.34".
// Notifies connected clients; value is always READ-able even when no client
// is connected, so the app can catch up on reconnect.
void publishWeight(float weight)
{
  char buf[12];
  snprintf(buf, sizeof(buf), "%.2f", weight);
  pWeightChar->setValue(buf);
  if (bleConnected) {
    pWeightChar->notify();
  }
  Serial.print("BLE publish: ");
  Serial.println(buf);
}

// ── Screens ───────────────────────────────────────────────────────────────

void showWelcomeScreen()
{
  lcd.clear();

  // Step 1 – dashes converge from both edges to fill both rows
  char buf[17];
  memset(buf, ' ', 16);
  buf[16] = '\0';
  for (int i = 0; i < 8; i++) {
    buf[i]      = '-';
    buf[15 - i] = '-';
    lcd.setCursor(0, 0);
    lcd.print(buf);
    lcd.setCursor(0, 1);
    lcd.print(buf);
    delay(38);
  }
  delay(250);

  // Step 2 – title: [flame] GasYangu [flame] with typewriter effect
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.write((uint8_t)0);
  typewrite(1, 0, " GasYangu ", 70);
  lcd.setCursor(15, 0);
  lcd.write((uint8_t)0);

  typewrite(1, 1, " Gas Monitor", 55);
  delay(1000);

  // Step 3 – loading bar sweeps across row 1
  lcd.setCursor(0, 1);
  lcd.print("                ");
  lcd.setCursor(0, 1);
  for (int i = 0; i < 16; i++) {
    lcd.write((uint8_t)255);            // solid block ▓
    delay(75);
  }
  delay(400);
}

// Shown on manual button wakeup only.
void showWakeupScreen()
{
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.write((uint8_t)0);
  lcd.print(" GasYangu ");
  lcd.write((uint8_t)0);
  lcd.setCursor(0, 1);
  lcd.print("   Monitoring!  ");
  delay(800);
}

void showWeightOnLcd(float weight)
{
  char buf[17];
  snprintf(buf, sizeof(buf), "   %7.2f kg   ", weight);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  Weight (kg)   ");
  lcd.setCursor(0, 1);
  lcd.print(buf);
}

// ── Sleep / wakeup ────────────────────────────────────────────────────────
// Arms both wakeup sources:
//   • GPIO5 LOW  – manual button press
//   • 5-min timer – periodic BLE publish
// After wakeup, restarts BLE advertising and shows the wakeup screen only
// for button presses (timer wakeups proceed silently to the weight reading).
void goToSleep()
{
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("   Sleeping...  ");
  lcd.setCursor(0, 1);
  lcd.print("  [Btn to wake] ");
  delay(1200);
  lcd.noBacklight();

  // Wait for button to be fully released before arming sleep.
  while (digitalRead(WAKEUP_CONFIG_PIN) == LOW) delay(10);
  delay(50);  // debounce

  esp_sleep_enable_timer_wakeup(SLEEP_DURATION_US);
  gpio_wakeup_enable(WAKEUP_CONFIG_PIN, GPIO_INTR_LOW_LEVEL);
  esp_sleep_enable_gpio_wakeup();
  esp_light_sleep_start();
  // ── resumes here ──────────────────────────────────────────────────────

  bleConnected = false;             // BLE connection dropped during sleep
  BLEDevice::startAdvertising();   // re-advertise after wakeup
  _wakeMillis = millis();          // start the active window

  lcd.backlight();
  lcd.createChar(0, flame);   // CGRAM is lost during sleep; restore the flame icon

  if (esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_GPIO) {
    showWakeupScreen();
  }
  // Timer wakeup: proceed silently straight to the weight read in loop().
}

// ── Arduino entry points ──────────────────────────────────────────────────

void setup()
{
  Serial.begin(115200);
  setCpuFrequencyMhz(80);

  pinMode(WAKEUP_CONFIG_PIN, INPUT_PULLUP);

  lcd.init();
  lcd.backlight();
  lcd.createChar(0, flame);

  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(calibration_factor);

  lcd.setCursor(0, 0);
  lcd.print("  Zeroing...    ");
  scale.tare();                         // zero with nothing on the scale
  lcd.clear();

  // ── BLE init ──────────────────────────────────────────────────────────
  BLEDevice::init("GasYangu");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new GasYanguServerCallbacks());

  BLEService *pService = pServer->createService(GASYANGU_SERVICE_UUID);

  pWeightChar = pService->createCharacteristic(
    WEIGHT_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pWeightChar->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising *pAdv = BLEDevice::getAdvertising();
  pAdv->addServiceUUID(GASYANGU_SERVICE_UUID);
  pAdv->setScanResponse(true);
  BLEDevice::startAdvertising();

  // Light sleep never re-enters setup(), so this is always a cold boot.
  showWelcomeScreen();
  _wakeMillis = millis();   // start the active window after the splash screen
}

void loop()
{
  float weight = scale.get_units();

  showWeightOnLcd(weight);
  publishWeight(weight);

  Serial.print("Weight: ");
  Serial.println(weight);

  // While the button is held, keep pushing the window forward so we never
  // call goToSleep() mid-press (which races with the LCD and causes garbage).
  if (digitalRead(WAKEUP_CONFIG_PIN) == LOW) {
    _wakeMillis = millis();
  }

  // Keep publishing until the active window expires, then sleep.
  if (millis() - _wakeMillis >= ACTIVE_WINDOW_MS) {
    goToSleep();
  } else {
    delay(PUBLISH_INTERVAL_MS);
  }
}