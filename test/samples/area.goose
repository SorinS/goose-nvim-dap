fn area(w: i64, h: i64) -> i64 {
    let a = w * h;
    return a;
}

fn main() {
    var total: i64 = 0;
    for i in 0..3 {
        total = total + area(i, 2);
    }
    print(total);
}
