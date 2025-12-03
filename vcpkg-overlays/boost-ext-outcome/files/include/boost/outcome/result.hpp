#pragma once

#include <expected>
#include <system_error>

namespace boost::outcome {

/// Lightweight stand-in for outcome::result implemented via std::expected
template <typename T, typename E = std::error_code>
using result = std::expected<T, E>;

} // namespace boost::outcome
