#pragma once

#include <cstddef>
#include <memory>

namespace qlibs {

struct default_allocator_policy {
    [[nodiscard]] constexpr std::size_t grow(std::size_t current) const noexcept {
        return current == 0 ? 8 : current * 2U;
    }
};

} // namespace qlibs
