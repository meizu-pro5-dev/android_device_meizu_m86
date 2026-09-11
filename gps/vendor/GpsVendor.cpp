/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * Flyme gpsd's imported Sensor/Manager/Queue ABI, implemented over the stable
 * frameworks.sensorservice HIDL interface. These types are private to gpsd;
 * no system libsensor/libgui or private sensor Binder parcel is involved.
 */
#define LOG_TAG "m86-gps-vendor"
#include <android/frameworks/sensorservice/1.0/ISensorManager.h>
#include <android/frameworks/sensorservice/1.0/IEventQueueCallback.h>
#include <android/sensor.h>
#include <hidl/HidlTransportSupport.h>
#include <sensors/convert.h>
#include <utils/Errors.h>
#include <utils/RefBase.h>
#include <utils/String8.h>
#include <utils/String16.h>
#include <log/log.h>
#include <openssl/ssl.h>
#include <sys/eventfd.h>
#include <unistd.h>
#include <errno.h>
#include <algorithm>
#include <deque>
#include <cstring>
#include <limits>
#include <memory>
#include <mutex>
#include <vector>

extern "C" const SSL_METHOD* SSLv3_client_method() {
    return TLS_client_method();
}

namespace android {
namespace fs = frameworks::sensorservice::V1_0;
namespace hs = hardware::sensors::V1_0;

static status_t status(const hardware::Return<fs::Result>& result) {
    if (!result.isOk()) return DEAD_OBJECT;
    switch (static_cast<fs::Result>(result)) {
        case fs::Result::OK: return OK;
        case fs::Result::NOT_EXIST: return NAME_NOT_FOUND;
        case fs::Result::NO_MEMORY: return NO_MEMORY;
        case fs::Result::NO_INIT: return NO_INIT;
        case fs::Result::PERMISSION_DENIED: return PERMISSION_DENIED;
        case fs::Result::BAD_VALUE: return BAD_VALUE;
        case fs::Result::INVALID_OPERATION: return INVALID_OPERATION;
        default: return UNKNOWN_ERROR;
    }
}

// gpsd receives opaque pointers and accesses these fields through the imported
// getters below. Keep String8 return-by-reference and scalar widths unchanged.
class Sensor {
public:
    explicit Sensor(const hs::SensorInfo& info)
        : mInfo(info), mName(info.name.c_str()), mVendor(info.vendor.c_str()) {}
    const String8& getName() const;
    const String8& getVendor() const;
    int32_t getHandle() const;
    int32_t getType() const;
    float getMaxValue() const;
    float getResolution() const;
    float getPowerUsage() const;
    int32_t getMinDelay() const;
private:
    hs::SensorInfo mInfo;
    String8 mName, mVendor;
};
const String8& Sensor::getName() const { return mName; }
const String8& Sensor::getVendor() const { return mVendor; }
int32_t Sensor::getHandle() const { return mInfo.sensorHandle; }
int32_t Sensor::getType() const { return static_cast<int32_t>(mInfo.type); }
float Sensor::getMaxValue() const { return mInfo.maxRange; }
float Sensor::getResolution() const { return mInfo.resolution; }
float Sensor::getPowerUsage() const { return mInfo.power; }
int32_t Sensor::getMinDelay() const { return mInfo.minDelay; }

class SensorEventQueue : public RefBase {
public:
    SensorEventQueue() : mFd(eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK)) {}
    ~SensorEventQueue() override { if (mFd >= 0) close(mFd); }
    bool initialize(const sp<fs::ISensorManager>& manager);
    int getFd() const;
    ssize_t read(ASensorEvent* events, size_t count);
    status_t enableSensor(const Sensor* sensor) const;
    status_t disableSensor(const Sensor* sensor) const;
    status_t setEventRate(const Sensor* sensor, int64_t ns) const;
    void enqueue(const hs::Event& event);
private:
    int mFd;
    sp<fs::IEventQueue> mRemote;
    std::mutex mLock;
    std::deque<ASensorEvent> mEvents;
};

class Callback : public fs::IEventQueueCallback {
public:
    explicit Callback(const sp<SensorEventQueue>& queue) : mQueue(queue) {}
    hardware::Return<void> onEvent(const hs::Event& event) override {
        const auto queue = mQueue.promote();
        if (queue != nullptr) queue->enqueue(event);
        return hardware::Void();
    }
private:
    wp<SensorEventQueue> mQueue;
};

bool SensorEventQueue::initialize(const sp<fs::ISensorManager>& manager) {
    if (mFd < 0 || manager == nullptr) return false;
    auto callback = sp<Callback>::make(sp<SensorEventQueue>::fromExisting(this));
    auto result = manager->createEventQueue(callback,
        [this](const sp<fs::IEventQueue>& queue, fs::Result result) {
            if (result == fs::Result::OK) mRemote = queue;
        });
    return result.isOk() && mRemote != nullptr;
}
int SensorEventQueue::getFd() const { return mFd; }
void SensorEventQueue::enqueue(const hs::Event& event) {
    sensors_event_t converted{};
    hs::implementation::convertToSensorEvent(event, &converted);
    static_assert(sizeof(converted) == sizeof(ASensorEvent));
    ASensorEvent output{};
    memcpy(&output, &converted, sizeof(output));
    std::lock_guard<std::mutex> guard(mLock);
    // Bound memory if the legacy reader stops draining. Retain recent samples.
    if (mEvents.size() == 1024) mEvents.pop_front();
    const bool wasEmpty = mEvents.empty();
    mEvents.push_back(output);
    if (wasEmpty) {
        uint64_t signal = 1;
        ssize_t result;
        do { result = ::write(mFd, &signal, sizeof(signal)); } while (result < 0 && errno == EINTR);
        if (result < 0 && errno != EAGAIN) ALOGE("eventfd write failed: %d", errno);
    }
}
ssize_t SensorEventQueue::read(ASensorEvent* events, size_t count) {
    if (events == nullptr || count == 0) return BAD_VALUE;
    std::lock_guard<std::mutex> guard(mLock);
    const size_t n = std::min(count, mEvents.size());
    for (size_t i = 0; i < n; ++i) {
        events[i] = mEvents.front();
        mEvents.pop_front();
    }
    if (mEvents.empty()) {
        uint64_t signal;
        while (::read(mFd, &signal, sizeof(signal)) < 0 && errno == EINTR) {}
    }
    return n ? static_cast<ssize_t>(n) : -EAGAIN;
}
status_t SensorEventQueue::enableSensor(const Sensor* sensor) const {
    if (!sensor || !mRemote) return BAD_VALUE;
    return status(mRemote->enableSensor(sensor->getHandle(), 200000, 0));
}
status_t SensorEventQueue::disableSensor(const Sensor* sensor) const {
    if (!sensor || !mRemote) return BAD_VALUE;
    return status(mRemote->disableSensor(sensor->getHandle()));
}
status_t SensorEventQueue::setEventRate(const Sensor* sensor, int64_t ns) const {
    if (!sensor || !mRemote || ns < 0 || ns / 1000 > INT32_MAX) return BAD_VALUE;
    return status(mRemote->enableSensor(sensor->getHandle(),
        static_cast<int32_t>(ns / 1000), 0));
}

class SensorManager {
public:
    static SensorManager& getInstanceForPackage(const String16& package);
    ssize_t getSensorList(const Sensor* const** list);
    const Sensor* getDefaultSensor(int type);
    sp<SensorEventQueue> createEventQueue(String8 package, int mode);
private:
    bool connect();
    sp<fs::ISensorManager> mManager;
    std::vector<std::unique_ptr<Sensor>> mOwned;
    std::vector<const Sensor*> mSensors;
    std::mutex mLock;
};
SensorManager& SensorManager::getInstanceForPackage(const String16&) {
    static SensorManager instance;
    static std::once_flag once;
    std::call_once(once, [] { hardware::configureRpcThreadpool(2, false); });
    return instance;
}
bool SensorManager::connect() {
    if (mManager != nullptr) return true;
    // gpsd starts before system_server. Match SensorManager's wait for the
    // framework service rather than permanently losing motion input on boot.
    auto manager = fs::ISensorManager::getService();
    if (!manager) return false;
    bool ok = false;
    auto result = manager->getSensorList([&](const auto& list, fs::Result status) {
        if (status != fs::Result::OK) return;
        for (const auto& info : list) {
            mOwned.push_back(std::make_unique<Sensor>(info));
            mSensors.push_back(mOwned.back().get());
        }
        ok = true;
    });
    if (!result.isOk() || !ok) return false;
    mManager = manager;
    return true;
}
ssize_t SensorManager::getSensorList(const Sensor* const** list) {
    if (!list) return BAD_VALUE;
    std::lock_guard<std::mutex> guard(mLock);
    *list = nullptr;
    if (!connect()) return NO_INIT;
    *list = mSensors.data();
    return mSensors.size();
}
const Sensor* SensorManager::getDefaultSensor(int type) {
    std::lock_guard<std::mutex> guard(mLock);
    if (!connect()) return nullptr;
    int handle = -1;
    auto result = mManager->getDefaultSensor(static_cast<hs::SensorType>(type),
        [&](const auto& info, fs::Result result) {
            if (result == fs::Result::OK) handle = info.sensorHandle;
        });
    if (!result.isOk()) return nullptr;
    for (const auto* sensor : mSensors)
        if (sensor->getHandle() == handle) return sensor;
    return nullptr;
}
sp<SensorEventQueue> SensorManager::createEventQueue(String8, int mode) {
    std::lock_guard<std::mutex> guard(mLock);
    // gpsd only uses NORMAL mode. Do not grant data injection semantics.
    if (mode != 0 || !connect()) return nullptr;
    auto queue = sp<SensorEventQueue>::make();
    if (!queue->initialize(mManager)) return nullptr;
    return queue;
}
} // namespace android

#ifdef M86_GPS_SENSOR_PROBE_MAIN
#include <poll.h>
#include <cstdio>
#include <cstdlib>
#include <time.h>
#include <utils/Timers.h>
int main(int argc, char** argv) {
    const int requestedType = argc > 1 ? std::atoi(argv[1]) : ASENSOR_TYPE_ACCELEROMETER;
    using namespace android;
    auto& manager = SensorManager::getInstanceForPackage(String16("m86.sensor.probe"));
    const Sensor* const* sensors = nullptr;
    const auto count = manager.getSensorList(&sensors);
    if (count <= 0) { fprintf(stderr, "sensor list failed: %zd\n", count); return 1; }
    const auto* sensor = manager.getDefaultSensor(requestedType);
    if (!sensor) { fprintf(stderr, "requested sensor unavailable\n"); return 2; }
    auto queue = manager.createEventQueue(String8("m86.sensor.probe"), 0);
    if (!queue) { fprintf(stderr, "queue creation failed\n"); return 3; }
    if (queue->enableSensor(sensor) != OK) return 4;
    if (queue->setEventRate(sensor, 20000000) != OK) {
        queue->disableSensor(sensor); return 5;
    }
    pollfd fd{queue->getFd(), POLLIN, 0};
    // A queue may first deliver metadata/additional-info events. Keep waiting
    // for an actual sample within one total deadline instead of treating the
    // first wakeup as an accelerometer reading.
    const auto deadline = systemTime(SYSTEM_TIME_MONOTONIC) + 5000000000LL;
    ssize_t received = 0;
    bool valid = false;
    while (!valid) {
        const auto remaining = deadline - systemTime(SYSTEM_TIME_MONOTONIC);
        if (remaining <= 0) break;
        const int ready = poll(&fd, 1, static_cast<int>((remaining + 999999) / 1000000));
        if (ready < 0 && errno == EINTR) continue;
        if (ready <= 0) break;
        ASensorEvent events[64]{};
        const auto count = queue->read(events, 64);
        if (count < 0) break;
        received += count;
        for (ssize_t i = 0; i < count; ++i) {
            timespec now{};
            if (clock_gettime(CLOCK_BOOTTIME, &now) != 0) return 7;
            const int64_t boot = now.tv_sec * 1000000000LL + now.tv_nsec;
            printf("event handle=%d type=%d timestamp=%lld boot=%lld age_ms=%.3f value=%.3f\n",
                events[i].sensor, events[i].type, static_cast<long long>(events[i].timestamp),
                static_cast<long long>(boot), (boot - events[i].timestamp) / 1000000.0,
                events[i].data[0]);
            if (events[i].sensor == sensor->getHandle() && events[i].timestamp > 0 &&
                    events[i].type == requestedType && events[i].timestamp <= boot + 1000000 &&
                    events[i].timestamp >= boot - 1000000000LL) valid = true;
        }
    }
    const auto disabled = queue->disableSensor(sensor);
    printf("sensors=%zd handle=%d name=%s events=%zd disable=%d valid=%d\n",
        count, sensor->getHandle(), sensor->getName().c_str(), received, disabled, valid);
    return valid && disabled == OK ? 0 : 6;
}
#endif
