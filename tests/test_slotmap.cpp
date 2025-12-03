#include <boost/ut.hpp>

int main() {
    using namespace boost::ut;

    "SlotMap smoke"_test = [] {
        expect(1_i == 1);
    };

    return 0;
}
