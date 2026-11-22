// The namespace assert.goose calls into.
namespace geo;

fn area(w: i64, h: i64) -> i64 {
    assert(w >= 0);
    return w * h;
}
