#pragma once
/**
 * BLE Health Service — GATT server exposing vitals to the Flutter app.
 *
 * Characteristics (UUIDs in config/config.h, mirrored in the mobile app):
 *   heart_rate / temperature / spo2 / battery : notify+read, float32 LE
 *   movement                                  : notify+read, 7×float32 LE
 *   command                                   : write ("mode:normal",
 *                                               "mode:powersave", "flush")
 *   device_info                               : read "fw=<v>;serial=<sn>"
 *
 * Security: pairing uses BLE bonding with Just Works + encrypted links
 * (ESP_LE_AUTH_REQ_SC_BOND). Characteristics require an encrypted link.
 */

#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLESecurity.h>
#include <BLEServer.h>
#include <BLEUtils.h>

#include <functional>
#include <string>

#include "config/config.h"
#include "core/sample.h"

namespace sb {

class HealthService {
 public:
  using CommandHandler = std::function<void(const std::string&)>;

  void begin(const std::string& serial_number, CommandHandler on_command) {
    on_command_ = std::move(on_command);

    BLEDevice::init((std::string(DEVICE_NAME_PREFIX) + serial_number).c_str());
    BLEDevice::setEncryptionLevel(ESP_BLE_SEC_ENCRYPT);

    // Bonding with secure connections; no display/keyboard on the bracelet.
    auto* security = new BLESecurity();
    security->setAuthenticationMode(ESP_LE_AUTH_REQ_SC_BOND);
    security->setCapability(ESP_IO_CAP_NONE);
    security->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);

    server_ = BLEDevice::createServer();
    server_->setCallbacks(new ServerCallbacks(this));

    // 7 characteristics → request enough handles.
    BLEService* service = server_->createService(BLEUUID(UUID_HEALTH_SERVICE), 32);

    hr_ = makeNotifyChar(service, UUID_CHAR_HEART_RATE);
    temp_ = makeNotifyChar(service, UUID_CHAR_TEMPERATURE);
    spo2_ = makeNotifyChar(service, UUID_CHAR_SPO2);
    movement_ = makeNotifyChar(service, UUID_CHAR_MOVEMENT);
    battery_ = makeNotifyChar(service, UUID_CHAR_BATTERY);

    command_ = service->createCharacteristic(
        UUID_CHAR_COMMAND, BLECharacteristic::PROPERTY_WRITE);
    command_->setAccessPermissions(ESP_GATT_PERM_WRITE_ENCRYPTED);
    command_->setCallbacks(new CommandCallbacks(this));

    device_info_ = service->createCharacteristic(
        UUID_CHAR_DEVICE_INFO, BLECharacteristic::PROPERTY_READ);
    device_info_->setAccessPermissions(ESP_GATT_PERM_READ_ENCRYPTED);
    const std::string info =
        "fw=" FIRMWARE_VERSION ";serial=" + serial_number;
    device_info_->setValue(info);

    service->start();

    BLEAdvertising* adv = BLEDevice::getAdvertising();
    adv->addServiceUUID(UUID_HEALTH_SERVICE);
    adv->setScanResponse(true);
    adv->setMinPreferred(0x06);
    BLEDevice::startAdvertising();
  }

  bool connected() const { return connected_; }

  /** Publish a sample: set values + notify subscribed centrals. */
  void publish(const Sample& s) {
    if (!connected_) return;
    uint8_t f32[4];
    if (!isnan(s.heart_rate)) {
      encode_f32_le(s.heart_rate, f32);
      hr_->setValue(f32, 4);
      hr_->notify();
    }
    if (!isnan(s.temperature)) {
      encode_f32_le(s.temperature, f32);
      temp_->setValue(f32, 4);
      temp_->notify();
    }
    if (!isnan(s.spo2)) {
      encode_f32_le(s.spo2, f32);
      spo2_->setValue(f32, 4);
      spo2_->notify();
    }
    uint8_t mv[28];
    encode_movement(s.movement, mv);
    movement_->setValue(mv, 28);
    movement_->notify();
    if (!isnan(s.battery_pct)) {
      encode_f32_le(s.battery_pct, f32);
      battery_->setValue(f32, 4);
      battery_->notify();
    }
  }

 private:
  static BLECharacteristic* makeNotifyChar(BLEService* service, const char* uuid) {
    auto* c = service->createCharacteristic(
        uuid, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
    c->setAccessPermissions(ESP_GATT_PERM_READ_ENCRYPTED);
    c->addDescriptor(new BLE2902());  // CCCD so centrals can subscribe
    return c;
  }

  class ServerCallbacks : public BLEServerCallbacks {
   public:
    explicit ServerCallbacks(HealthService* svc) : svc_(svc) {}
    void onConnect(BLEServer*) override { svc_->connected_ = true; }
    void onDisconnect(BLEServer*) override {
      svc_->connected_ = false;
      BLEDevice::startAdvertising();  // resume so the app can reconnect
    }

   private:
    HealthService* svc_;
  };

  class CommandCallbacks : public BLECharacteristicCallbacks {
   public:
    explicit CommandCallbacks(HealthService* svc) : svc_(svc) {}
    void onWrite(BLECharacteristic* c) override {
      if (svc_->on_command_) svc_->on_command_(c->getValue());
    }

   private:
    HealthService* svc_;
  };

  BLEServer* server_ = nullptr;
  BLECharacteristic* hr_ = nullptr;
  BLECharacteristic* temp_ = nullptr;
  BLECharacteristic* spo2_ = nullptr;
  BLECharacteristic* movement_ = nullptr;
  BLECharacteristic* battery_ = nullptr;
  BLECharacteristic* command_ = nullptr;
  BLECharacteristic* device_info_ = nullptr;
  volatile bool connected_ = false;
  CommandHandler on_command_;
};

}  // namespace sb
