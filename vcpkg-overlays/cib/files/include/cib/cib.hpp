#pragma once

#include <cstdint>
#include <utility>

namespace cib {

struct version {
    std::uint32_t major;
    std::uint32_t minor;
    std::uint32_t patch;
};

constexpr version current_version{1, 0, 0};

template <typename T>
struct service {
    using type = T;
};

} // namespace cib
