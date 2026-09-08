#include <array>
#include <cassert>
#include <cstring>
#include <iostream>
#include "M86DiscoveryCompat.h"
int main() {
  // Normal discovery list captured from this phone's GSI startup.
  std::array<uint8_t,16> observed{0x21,3,13,6,0,1,1,1,2,1,0x80,1,6,1,0x70,1};
  const std::array<uint8_t,14> expected{0x21,3,11,5,0,1,1,1,2,1,0x80,1,6,1};
  uint16_t size=observed.size();
  assert(m86FilterDiscovery(&size,observed.data()));
  assert(size==expected.size());
  assert(std::memcmp(observed.data(),expected.data(),size)==0);
  assert(!m86FilterDiscovery(&size,observed.data()));
  std::array<uint8_t,8> supported{0x21,3,5,2,0,1,1,1};
  auto copy=supported; size=supported.size();
  assert(!m86FilterDiscovery(&size,supported.data())); assert(supported==copy);
  std::array<uint8_t,6> unrelated{0x20,3,3,1,0x70,1};
  auto other=unrelated; size=unrelated.size();
  assert(!m86FilterDiscovery(&size,unrelated.data())); assert(unrelated==other);
  std::array<uint8_t,6> unsupported{0x21,3,3,1,0x70,1};
  auto only=unsupported; size=unsupported.size();
  assert(!m86FilterDiscovery(&size,unsupported.data())); assert(unsupported==only);
  uint8_t shortHeader[2]={0x21,3}; size=2;
  assert(!m86FilterDiscovery(&size,shortHeader));
  assert(!m86FilterDiscovery(nullptr,nullptr));
  std::cout << "GSI discovery trace translated; supported modes/frequencies preserved; unrelated and unsupported-only requests unchanged; short-header guard passed.\n";
}
