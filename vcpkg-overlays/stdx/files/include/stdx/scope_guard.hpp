#pragma once

#include <utility>

namespace stdx {

/// scope guard helper for quick cleanup lambdas
template <typename F>
class scope_guard {
public:
    explicit scope_guard(F&& fn) noexcept : fn_(static_cast<F&&>(fn)), active_(true) {}
    scope_guard(scope_guard&& other) noexcept : fn_(static_cast<F&&>(other.fn_)), active_(other.active_) { other.active_ = false; }
    scope_guard(const scope_guard&) = delete;
    scope_guard& operator=(const scope_guard&) = delete;
    ~scope_guard() {
        if (active_) {
            fn_();
        }
    }

    void release() noexcept { active_ = false; }

private:
    F fn_;
    bool active_;
};

template <typename F>
scope_guard(F) -> scope_guard<F>;

} // namespace stdx
