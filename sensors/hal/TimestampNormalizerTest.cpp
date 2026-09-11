// SPDX-License-Identifier: Apache-2.0
#include "TimestampNormalizer.h"
#include <cassert>
#include <climits>
int main() {
    using namespace m86;
    const int64_t epoch = 1788936000LL * kSecond;
    Clocks a{100*kSecond, epoch, true}, b{101*kSecond, epoch+kSecond, true};
    int64_t result = 0;
    assert(normalizeTimestamp(epoch+500000000, a, b, &result));
    assert(result == 100*kSecond+500000000); // Preserve capture time, not poll time.
    Clocks wake{161*kSecond, epoch+61*kSecond, true};
    assert(normalizeTimestamp(epoch+61*kSecond-20000000, b, wake, &result));
    assert(result == wake.boot-20000000); // Suspend advances both clocks equally.
    Clocks jump{102*kSecond, epoch+3602*kSecond, true};
    assert(!normalizeTimestamp(jump.real, b, jump, &result));
    Clocks settled{103*kSecond, jump.real+kSecond, true};
    assert(normalizeTimestamp(settled.real, jump, settled, &result));
    assert(result == settled.boot); // Recover with a new offset, not startup offset.
    assert(!normalizeTimestamp(epoch-20*kSecond, a, b, &result));
    assert(!normalizeTimestamp(LLONG_MAX, a, b, &result));
    assert(!normalizeTimestamp(LLONG_MIN, a, b, &result));
    assert(!normalizeTimestamp(epoch, {}, b, &result));
    assert(!normalizeTimestamp(b.real+2000000, a, b, &result));
    assert(isLegacyInputSensor(4,5) && isLegacyInputSensor(3,8));
    assert(isLegacyInputSensor(27,8));
    assert(!isLegacyInputSensor(0,1) && !isLegacyInputSensor(3,0));
    assert(!isLegacyInputSensor(4,0) && !isLegacyInputSensor(31,5));
}
