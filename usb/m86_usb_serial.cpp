// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0

#include <android/log.h>
#include <cutils/properties.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>

#include <array>
#include <string>

namespace {

constexpr char kLogTag[] = "m86_usb_serial";
constexpr size_t kPrivateSlotSize = 1024;
constexpr size_t kPrivateSignatureSize = 256;
constexpr size_t kPrivateLengthSize = sizeof(uint16_t);
constexpr size_t kPrivateDataOffset =
    kPrivateSignatureSize + kPrivateLengthSize;
constexpr size_t kMinSerialLength = 4;
constexpr size_t kMaxSerialLength = 64;
constexpr useconds_t kRetryDelayUs = 100000;
constexpr unsigned int kRetryCount = 100;

constexpr std::array<const char*, 3> kPrivatePaths = {{
    "/dev/block/platform/15570000.ufs/by-name/private",
    "/dev/block/by-name/private",
    "/dev/block/sda1",
}};

constexpr char kUsbEnablePath[] =
    "/sys/class/android_usb/android0/enable";
constexpr char kUsbSerialPath[] =
    "/sys/class/android_usb/android0/iSerial";

bool PreadFully(int fd, uint8_t* data, size_t size) {
  size_t offset = 0;
  while (offset < size) {
    const ssize_t result = pread(fd, data + offset, size - offset, offset);
    if (result < 0 && errno == EINTR) {
      continue;
    }
    if (result <= 0) {
      return false;
    }
    offset += static_cast<size_t>(result);
  }
  return true;
}

bool IsUsbSerialCharacter(char value) {
  return (value >= '0' && value <= '9') ||
      (value >= 'A' && value <= 'Z') ||
      (value >= 'a' && value <= 'z') || value == '-' || value == '_' ||
      value == '.';
}

bool ParsePrivateSerial(const std::array<uint8_t, kPrivateSlotSize>& slot,
                        std::string* serial) {
  const size_t length = static_cast<size_t>(slot[kPrivateSignatureSize]) |
      (static_cast<size_t>(slot[kPrivateSignatureSize + 1]) << 8);
  if (length < kMinSerialLength || length > kMaxSerialLength ||
      length > slot.size() - kPrivateDataOffset) {
    return false;
  }

  const char* data = reinterpret_cast<const char*>(
      slot.data() + kPrivateDataOffset);
  for (size_t index = 0; index < length; ++index) {
    if (!IsUsbSerialCharacter(data[index])) {
      return false;
    }
  }
  serial->assign(data, length);
  return true;
}

bool ReadPrivateSerial(std::string* serial, const char** source_path) {
  std::array<uint8_t, kPrivateSlotSize> slot = {};
  for (const char* path : kPrivatePaths) {
    const int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
      continue;
    }
    const bool read_ok = PreadFully(fd, slot.data(), slot.size());
    close(fd);
    if (read_ok && ParsePrivateSerial(slot, serial)) {
      *source_path = path;
      return true;
    }
  }
  return false;
}

bool ReadText(const char* path, std::string* value) {
  const int fd = open(path, O_RDONLY | O_CLOEXEC);
  if (fd < 0) {
    return false;
  }

  std::array<char, 32> buffer = {};
  ssize_t result;
  do {
    result = read(fd, buffer.data(), buffer.size() - 1);
  } while (result < 0 && errno == EINTR);
  close(fd);
  if (result <= 0) {
    return false;
  }

  value->assign(buffer.data(), static_cast<size_t>(result));
  while (!value->empty() &&
         (value->back() == '\n' || value->back() == '\r' ||
          value->back() == ' ' || value->back() == '\t')) {
    value->pop_back();
  }
  return true;
}

bool WriteText(const char* path, const std::string& value) {
  const int fd = open(path, O_WRONLY | O_CLOEXEC);
  if (fd < 0) {
    return false;
  }

  size_t offset = 0;
  while (offset < value.size()) {
    const ssize_t result = write(fd, value.data() + offset,
                                 value.size() - offset);
    if (result < 0 && errno == EINTR) {
      continue;
    }
    if (result <= 0) {
      close(fd);
      return false;
    }
    offset += static_cast<size_t>(result);
  }
  close(fd);
  return true;
}

bool WaitForUsbGadget() {
  for (unsigned int attempt = 0; attempt < kRetryCount; ++attempt) {
    if (access(kUsbSerialPath, F_OK) == 0 &&
        access(kUsbEnablePath, F_OK) == 0) {
      return true;
    }
    usleep(kRetryDelayUs);
  }
  return false;
}

}  // namespace

int main() {
  std::string serial;
  const char* source_path = nullptr;
  for (unsigned int attempt = 0; attempt < kRetryCount; ++attempt) {
    if (ReadPrivateSerial(&serial, &source_path)) {
      break;
    }
    usleep(kRetryDelayUs);
  }
  if (serial.empty()) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "unable to read a valid serial from private slot 0");
    return 1;
  }

  if (!WaitForUsbGadget()) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "android_usb sysfs did not become available");
    return 1;
  }

  std::string enabled;
  const bool was_enabled = ReadText(kUsbEnablePath, &enabled) && enabled == "1";
  if (was_enabled && !WriteText(kUsbEnablePath, "0")) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "unable to disable android_usb before serial update");
    return 1;
  }

  if (!WriteText(kUsbSerialPath, serial)) {
    if (was_enabled) {
      WriteText(kUsbEnablePath, "1");
    }
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "unable to publish the private-slot USB serial");
    return 1;
  }

  if (was_enabled && !WriteText(kUsbEnablePath, "1")) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "unable to re-enable android_usb after serial update");
    return 1;
  }

  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "installed %zu-byte USB serial from %s", serial.size(),
                      source_path);
  if (property_set("vendor.m86.identity.ready", "1") != 0) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "unable to publish identity readiness");
    return 1;
  }
  return 0;
}
