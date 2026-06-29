/*
 * ESP32 Rover Controller Firmware
 * Handles: Motor control + Servo + HTTP command endpoint
 *
 * Wiring (example):
 *   Motor driver IN1 -> GPIO 26
 *   Motor driver IN2 -> GPIO 27
 *   Motor driver IN3 -> GPIO 14
 *   Motor driver IN4 -> GPIO 12
 *   ENA (speed L) -> GPIO 25
 *   ENB (speed R) -> GPIO 33
 *   Servo -> GPIO 13
 *
 * Access point: connects to phone hotspot
 * Hostname: rover.local (mDNS)
 *
 * Endpoints:
 *   GET /move?dir=forward|back|left|right|stop
 *   GET /servo?angle=0-180
 *   GET /status
 *   GET /battery  (NEW)
 */

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ESP32Servo.h>

// ─── Wi-Fi credentials (your phone hotspot) ───────────────────
const char* WIFI_SSID     = "YOUR_HOTSPOT_SSID";
const char* WIFI_PASSWORD = "YOUR_HOTSPOT_PASSWORD";
const char* HOSTNAME      = "rover";

// ─── Battery monitoring (NEW) ─────────────────────────────────
const int BATTERY_PIN = 34;        // GPIO34 (ADC1_CH6)
const float VOLTAGE_MAX = 8.4;     // Fully charged 2S Li-ion
const float VOLTAGE_MIN = 6.0;     // Cutoff voltage
const float VOLTAGE_DIVIDER = 4.7; // (R1+R2)/R2 = (100+27)/27 ≈ 4.7
const int ADC_MAX = 4095;          // 12-bit ADC
const float ADC_REF_VOLTAGE = 3.3; // ESP32 reference voltage
const int BATTERY_SAMPLES = 10;    // Number of samples for averaging

// ─── Motor pins ───────────────────────────────────────────────
#define MOTOR_L_IN1  26
#define MOTOR_L_IN2  27
#define MOTOR_R_IN1  14
#define MOTOR_R_IN2  12
#define MOTOR_L_EN   25   // PWM speed left
#define MOTOR_R_EN   33   // PWM speed right

// ─── Servo pin ────────────────────────────────────────────────
#define SERVO_PIN    13

// ─── Safety timeout ───────────────────────────────────────────
#define CMD_TIMEOUT_MS 2000   // stop if no command in 2s

// ─── Speed 0-255 ──────────────────────────────────────────────
#define FULL_SPEED   200
#define TURN_SPEED   170

WebServer server(80);
Servo tiltServo;

unsigned long lastCommandTime = 0;
String lastDirection = "stop";

// ─── Motor helpers ────────────────────────────────────────────
void setMotors(bool l1, bool l2, bool r1, bool r2,
               int lSpeed = FULL_SPEED, int rSpeed = FULL_SPEED) {
  digitalWrite(MOTOR_L_IN1, l1);
  digitalWrite(MOTOR_L_IN2, l2);
  digitalWrite(MOTOR_R_IN1, r1);
  digitalWrite(MOTOR_R_IN2, r2);
  analogWrite(MOTOR_L_EN, lSpeed);
  analogWrite(MOTOR_R_EN, rSpeed);
}

void driveForward()  { setMotors(1,0, 1,0); }
void driveBackward() { setMotors(0,1, 0,1); }
void turnLeft()      { setMotors(0,1, 1,0, TURN_SPEED, TURN_SPEED); }
void turnRight()     { setMotors(1,0, 0,1, TURN_SPEED, TURN_SPEED); }
void motorStop()     { setMotors(0,0, 0,0, 0, 0); }

void applyDirection(String dir) {
  if      (dir == "forward") driveForward();
  else if (dir == "back")    driveBackward();
  else if (dir == "left")    turnLeft();
  else if (dir == "right")   turnRight();
  else                       motorStop();
  lastDirection = dir;
  lastCommandTime = millis();
}

// ─── Battery functions (NEW) ──────────────────────────────────
float readBatteryVoltage() {
  int rawADC = 0;
  for (int i = 0; i < BATTERY_SAMPLES; i++) {
    rawADC += analogRead(BATTERY_PIN);
    delay(2);
  }
  rawADC = rawADC / BATTERY_SAMPLES;
  
  float voltage = (rawADC / (float)ADC_MAX) * ADC_REF_VOLTAGE * VOLTAGE_DIVIDER;
  return voltage;
}

int calculateBatteryPercentage(float voltage) {
  if (voltage >= VOLTAGE_MAX) return 100;
  if (voltage <= VOLTAGE_MIN) return 0;
  
  float percentage = ((voltage - VOLTAGE_MIN) / (VOLTAGE_MAX - VOLTAGE_MIN)) * 100;
  return constrain((int)percentage, 0, 100);
}

String getBatteryStatus() {
  float voltage = readBatteryVoltage();
  int percent = calculateBatteryPercentage(voltage);
  
  String json = "{\"battery_percent\": " + String(percent) + 
                ", \"voltage\": " + String(voltage, 2) + "}";
  return json;
}

// ─── HTTP handlers ────────────────────────────────────────────
void handleMove() {
  if (server.hasArg("dir")) {
    String dir = server.arg("dir");
    applyDirection(dir);
    server.send(200, "text/plain", "OK:" + dir);
  } else {
    server.send(400, "text/plain", "Missing dir param");
  }
}

void handleServo() {
  if (server.hasArg("angle")) {
    int angle = server.arg("angle").toInt();
    angle = constrain(angle, 0, 180);
    tiltServo.write(angle);
    lastCommandTime = millis();
    server.send(200, "text/plain", "SERVO:" + String(angle));
  } else {
    server.send(400, "text/plain", "Missing angle param");
  }
}

void handleStatus() {
  String json = "{\"status\":\"ok\",\"last\":\"" + lastDirection + "\",\"uptime\":" 
                + String(millis()) + "}";
  server.send(200, "application/json", json);
}

// ─── NEW: Battery handler ─────────────────────────────────────
void handleBattery() {
  server.send(200, "application/json", getBatteryStatus());
}

void handleNotFound() {
  server.send(404, "text/plain", "Not found");
}

// ─── Setup ────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  // Motor pins
  pinMode(MOTOR_L_IN1, OUTPUT);
  pinMode(MOTOR_L_IN2, OUTPUT);
  pinMode(MOTOR_R_IN1, OUTPUT);
  pinMode(MOTOR_R_IN2, OUTPUT);
  pinMode(MOTOR_L_EN, OUTPUT);
  pinMode(MOTOR_R_EN, OUTPUT);
  motorStop();

  // Servo
  ESP32PWM::allocateTimer(0);
  tiltServo.setPeriodHertz(50);
  tiltServo.attach(SERVO_PIN, 500, 2400);
  tiltServo.write(90);

  // ─── NEW: Battery ADC setup ────────────────────────────────
  analogReadResolution(12);  // Set ADC to 12-bit resolution
  pinMode(BATTERY_PIN, INPUT);

  // Wi-Fi
  Serial.print("Connecting to ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected! IP: " + WiFi.localIP().toString());

  // mDNS
  if (!MDNS.begin(HOSTNAME)) {
    Serial.println("mDNS failed");
  } else {
    Serial.println("mDNS: rover.local");
    MDNS.addService("http", "tcp", 80);
  }

  // Routes
  server.on("/move",     HTTP_GET, handleMove);
  server.on("/servo",    HTTP_GET, handleServo);
  server.on("/status",   HTTP_GET, handleStatus);
  server.on("/battery",  HTTP_GET, handleBattery);  // ─── NEW ROUTE ───
  server.onNotFound(handleNotFound);
  server.begin();

  Serial.println("HTTP server started");
  Serial.println("Available endpoints:");
  Serial.println("  /move?dir=forward|back|left|right|stop");
  Serial.println("  /servo?angle=0-180");
  Serial.println("  /status");
  Serial.println("  /battery  (NEW)");
  
  lastCommandTime = millis();
}

// ─── Loop ─────────────────────────────────────────────────────
void loop() {
  server.handleClient();

  // Safety watchdog: stop if no command received in CMD_TIMEOUT_MS
  if (millis() - lastCommandTime > CMD_TIMEOUT_MS &&
      lastDirection != "stop") {
    Serial.println("Watchdog: stopping rover");
    motorStop();
    lastDirection = "stop";
  }

  delay(2);
}