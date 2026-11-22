// A failed assert in a namespaced function (geo.goose): its C name
// geo_area_g3 shows as geo::area.

import geo;

fn total(n: i64) -> i64 {
    var sum: i64 = 0;
    for i in 0..n {
        sum = sum + geo::area(2 - i, 3);
    }
    return sum;
}

fn main() {
    print(total(4));
}
