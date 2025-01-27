pragma circom 2.0.0;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////// Templates from the circomlib ////////////////////////////////
////////////////// Copy-pasted here for easy reference //////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

template Exp () {
    signal input in[2];
    signal output out;

    var NUM_BITS = 8; 

    signal exp[NUM_BITS];
    signal inter[NUM_BITS];
    signal temp[NUM_BITS];

    component num2Bits = Num2Bits(NUM_BITS);
    num2Bits.in <== in[1];

    exp[0] <== in[0];
    inter[0] <== 1;
    for (var i = 0; i < NUM_BITS; i++) {
        temp[i] <== num2Bits.bits[i] * exp[i] + (1 - num2Bits.bits[i]); 
        if (i < NUM_BITS - 1) {
            inter[i + 1] <== inter[i] * temp[i];
            exp[i + 1] <== exp[i] * exp[i];
        } else {
            out <== inter[i] * temp[i];
        }
    }
}

/*
 * Outputs `a` AND `b`
 */
template AND() {
    signal input a;
    signal input b;
    signal output out;

    out <== a*b;
}

/*
 * Outputs `a` OR `b`
 */
template OR() {
    signal input a;
    signal input b;
    signal output out;

    out <== a + b - a*b;
}

/*
 * `out` = `cond` ? `L` : `R`
 */
template IfThenElse() {
    signal input cond;
    signal input L;
    signal input R;
    signal output out;

    out <== cond * (L - R) + R;
}

/*
 * (`outL`, `outR`) = `sel` ? (`R`, `L`) : (`L`, `R`)
 */
template Switcher() {
    signal input sel;
    signal input L;
    signal input R;
    signal output outL;
    signal output outR;

    signal aux;

    aux <== (R-L)*sel;
    outL <==  aux + L;
    outR <== -aux + R;
}

/*
 * Decomposes `in` into `b` bits, given by `bits`.
 * Least significant bit in `bits[0]`.
 * Enforces that `in` is at most `b` bits long.
 */
template Num2Bits(b) {
    signal input in;
    signal output bits[b];

    for (var i = 0; i < b; i++) {
        bits[i] <-- (in >> i) & 1;
        bits[i] * (1 - bits[i]) === 0;
    }
    var sum_of_bits = 0;
    for (var i = 0; i < b; i++) {
        sum_of_bits += (2 ** i) * bits[i];
    }
    //sum_of_bits === in;
}

/*
 * Reconstructs `out` from `b` bits, given by `bits`.
 * Least significant bit in `bits[0]`.
 */
template Bits2Num(b) {
    signal input bits[b];
    signal output out;
    var lc = 0;

    for (var i = 0; i < b; i++) {
        lc += (bits[i] * (1 << i));
    }
    out <== lc;
}

/*
 * Checks if `in` is zero and returns the output in `out`.
 */
template IsZero() {
    signal input in;
    signal output out;

    signal inv;

    inv <-- in!=0 ? 1/in : 0;

    out <== -in*inv +1;
    in*out === 0;
}

/*
 * Checks if `in[0]` == `in[1]` and returns the output in `out`.
 */
template IsEqual() {
    signal input in[2];
    signal output out;

    component isz = IsZero();

    in[1] - in[0] ==> isz.in;

    isz.out ==> out;
}

/*
 * Checks if `in[0]` < `in[1]` and returns the output in `out`.
 * Assumes `n` bit inputs. The behavior is not well-defined if any input is more than `n`-bits long.
 */
template LessThan(n) {
    assert(n <= 252);
    signal input in[2];
    signal output out;

    component n2b = Num2Bits(n+1);

    n2b.in <== in[0]+ (1<<n) - in[1];

    out <== 1-n2b.bits[n];
}

/////////////////////////////////////////////////////////////////////////////////////
///////////////////////// Templates for this lab ////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

/*
 * Outputs `out` = 1 if `in` is at most `b` bits long, and 0 otherwise.
 */
template CheckBitLength(b) {
    assert(b < 254);
    signal input in;
    signal output out;

    component n2b = Num2Bits(b+1);
    n2b.in <== in;

    out <== 1-n2b.bits[b];
}

/*
 * Enforces the well-formedness of an exponent-mantissa pair (e, m), which is defined as follows:
 * if `e` is zero, then `m` must be zero
 * else, `e` must be at most `k` bits long, and `m` must be in the range [2^p, 2^p+1)
 */
template CheckWellFormedness(k, p) {
    signal input e;
    signal input m;

    // check if `e` is zero
    component is_e_zero = IsZero();
    is_e_zero.in <== e;

    // Case I: `e` is zero
    //// `m` must be zero
    component is_m_zero = IsZero();
    is_m_zero.in <== m;

    // Case II: `e` is nonzero
    //// `e` is `k` bits
    component check_e_bits = CheckBitLength(k);
    check_e_bits.in <== e;
    //// `m` is `p`+1 bits with the MSB equal to 1
    //// equivalent to check `m` - 2^`p` is in `p` bits
    component check_m_bits = CheckBitLength(p);
    check_m_bits.in <== m - (1 << p);

    // choose the right checks based on `is_e_zero`
    component if_else = IfThenElse();
    if_else.cond <== is_e_zero.out;
    if_else.L <== is_m_zero.out;
    //// check_m_bits.out * check_e_bits.out is equivalent to check_m_bits.out AND check_e_bits.out
    if_else.R <== check_m_bits.out * check_e_bits.out;

    // assert that those checks passed
    if_else.out === 1;
}

/*
 * Right-shifts `b`-bit long `x` by `shift` bits to output `y`, where `shift` is a public circuit parameter.
 */
template RightShift(b, shift) {
    assert(shift < b);
    signal input x;
    signal output y;

    signal shifted[b];

    component n2b = Num2Bits(b);
    n2b.in <== x;

    for ( var i = 0; i < b - shift; i++) {
        shifted[i] <== n2b.bits[i + shift];
    }

    for ( var i = b - shift; i < b; i++) {
        shifted[i] <== 0;
    }

    component b2n = Bits2Num(b);
    b2n.bits <== shifted;
    y <== b2n.out;

}

/*
 * Rounds the input floating-point number and checks to ensure that rounding does not make the mantissa unnormalized.
 * Rounding is necessary to prevent the bitlength of the mantissa from growing with each successive operation.
 * The input is a normalized floating-point number (e, m) with precision `P`, where `e` is a `k`-bit exponent and `m` is a `P`+1-bit mantissa.
 * The output is a normalized floating-point number (e_out, m_out) representing the same value with a lower precision `p`.
 */
template RoundAndCheck(k, p, P) {
    signal input e;
    signal input m;
    signal output e_out;
    signal output m_out;
    assert(P > p);

    // check if no overflow occurs
    component if_no_overflow = LessThan(P+1);
    if_no_overflow.in[0] <== m;
    if_no_overflow.in[1] <== (1 << (P+1)) - (1 << (P-p-1));
    signal no_overflow <== if_no_overflow.out;

    var round_amt = P-p;
    // Case I: no overflow
    // compute (m + 2^{round_amt-1}) >> round_amt
    var m_prime = m + (1 << (round_amt-1));
    //// Although m_prime is P+1 bits long in no overflow case, it can be P+2 bits long
    //// in the overflow case and the constraints should not fail in either case
    component right_shift = RightShift(P+2, round_amt);
    right_shift.x <== m_prime;
    var m_out_1 = right_shift.y;
    var e_out_1 = e;

    // Case II: overflow
    var e_out_2 = e + 1;
    var m_out_2 = (1 << p);

    // select right output based on no_overflow
    component if_else[2];
    for (var i = 0; i < 2; i++) {
        if_else[i] = IfThenElse();
        if_else[i].cond <== no_overflow;
    }
    if_else[0].L <== e_out_1;
    if_else[0].R <== e_out_2;
    if_else[1].L <== m_out_1;
    if_else[1].R <== m_out_2;
    e_out <== if_else[0].out;
    m_out <== if_else[1].out;
}

/*
 * Left-shifts `x` by `shift` bits to output `y`.
 * Enforces 0 <= `shift` < `shift_bound`.
 * If `skip_checks` = 1, then we don't care about the output and the `shift_bound` constraint is not enforced.
 */
template LeftShift(shift_bound) {
    signal input x;
    signal input shift;
    signal input skip_checks;
    signal output y;

    component check_shift_bits = LessThan(shift_bound);
    check_shift_bits.in[0] <== shift;
    check_shift_bits.in[1] <== shift_bound;


    component if_else = IfThenElse();
    if_else.cond <== skip_checks;
    if_else.L <== 1;
    if_else.R <== check_shift_bits.out;

    if_else.out === 1;

    component exp = Exp();
    exp.in[0] <== 2;
    exp.in[1] <== shift;
    y <== x * exp.out;

}

/*
 * Find the Most-Significant Non-Zero Bit (MSNZB) of `in`, where `in` is assumed to be non-zero value of `b` bits.
 * Outputs the MSNZB as a one-hot vector `one_hot` of `b` bits, where `one_hot`[i] = 1 if MSNZB(`in`) = i and 0 otherwise.
 * The MSNZB is output as a one-hot vector to reduce the number of constraints in the subsequent `Normalize` template.
 * Enforces that `in` is non-zero as MSNZB(0) is undefined.
 * If `skip_checks` = 1, then we don't care about the output and the non-zero constraint is not enforced.
 */
template MSNZB(b) {
    signal input in;
    signal input skip_checks;
    signal output one_hot[b];
    
    component is_zero = IsZero();
    is_zero.in <== in;
    
    component if_else = IfThenElse();
    if_else.cond <== skip_checks;
    if_else.L <== 0;
    if_else.R <== is_zero.out;

    if_else.out === 0;

    component n2b_input = Num2Bits(b);
    n2b_input.in <== in;

    //find most significant index
    var ms_index = b-1;
    component if_else_msb[b];
    for (var i = 0; i < b; i++) {
        if_else_msb[i] = IfThenElse();
        if_else_msb[i].cond <== n2b_input.bits[i];
        if_else_msb[i].L <== i;
        if_else_msb[i].R <== ms_index;
        ms_index = if_else_msb[i].out;
    }

    // set one_hot vector using ms_index and IfThenElse template
    component if_else_one_hot[b];
    component is_equal[b];
    for (var i = 0; i < b; i++) {
        is_equal[i] = IsEqual();
        is_equal[i].in[0] <== i;
        is_equal[i].in[1] <== ms_index;
        if_else_one_hot[i] = IfThenElse();
        if_else_one_hot[i].cond <== is_equal[i].out;
        if_else_one_hot[i].L <== 1;
        if_else_one_hot[i].R <== 0;
        one_hot[i] <== if_else_one_hot[i].out;
    }
}

/*
 * Normalizes the input floating-point number.
 * The input is a floating-point number with a `k`-bit exponent `e` and a `P`+1-bit *unnormalized* mantissa `m` with precision `p`, where `m` is assumed to be non-zero.
 * The output is a floating-point number representing the same value with exponent `e_out` and a *normalized* mantissa `m_out` of `P`+1-bits and precision `P`.
 * Enforces that `m` is non-zero as a zero-value can not be normalized.
 * If `skip_checks` = 1, then we don't care about the output and the non-zero constraint is not enforced.
 */
template Normalize(k, p, P) {
    signal input e;
    signal input m;
    signal input skip_checks;
    signal output e_out;
    signal output m_out;
    assert(P > p);

    component is_zero = IsZero();
    is_zero.in <== m;
    
    component if_else = IfThenElse();
    if_else.cond <== skip_checks;
    if_else.L <== 0;
    if_else.R <== is_zero.out;

    if_else.out === 0;

    component n2b_input = Num2Bits(P+1);
    n2b_input.in <== m;
    
    var ms_index = P;
    component if_else_msb[P+1];
    for (var i = 0; i < P+1; i++) {
        if_else_msb[i] = IfThenElse();
        if_else_msb[i].cond <== n2b_input.bits[i];
        if_else_msb[i].L <== i;
        if_else_msb[i].R <== ms_index;
        ms_index = if_else_msb[i].out;
    }

    component left_shift = LeftShift(P+1);
    left_shift.x <== m;
    left_shift.shift <== P - ms_index;
    left_shift.skip_checks <== skip_checks;

    signal e_tmp <== e + ms_index - p;

    e_out <== e_tmp;
    m_out <== left_shift.y;
}

/*
 * Adds two floating-point numbers.
 * The inputs are normalized floating-point numbers with `k`-bit exponents `e` and `p`+1-bit mantissas `m` with scale `p`.
 * Does not assume that the inputs are well-formed and makes appropriate checks for the same.
 * The output is a normalized floating-point number with exponent `e_out` and mantissa `m_out` of `p`+1-bits and scale `p`.
 * Enforces that inputs are well-formed.
 */
template FloatAdd(k, p) {
    signal input e[2];
    signal input m[2];
    signal output e_out;
    signal output m_out;

    component checkWF[2];
    checkWF[0] = CheckWellFormedness(k, p);
    checkWF[0].e <== e[0];
    checkWF[0].m <== m[0];
    checkWF[1] = CheckWellFormedness(k, p);
    checkWF[1].e <== e[1];
    checkWF[1].m <== m[1];

    // (e[0] << (p+1))
    component left_shift[2];
    left_shift[0] = LeftShift(k+p+1);
    left_shift[0].x <== e[0];
    left_shift[0].shift <== p+1;
    left_shift[0].skip_checks <== 1;
    left_shift[1] = LeftShift(k+p+1);
    left_shift[1].x <== e[1];
    left_shift[1].shift <== p+1;
    left_shift[1].skip_checks <== 1;

    // (e_1 << (p+1)) + m_1
    signal mgn_1 <== left_shift[0].y + m[0];
    // (e_2 << (p+1)) + m_2
    signal mgn_2 <== left_shift[1].y + m[1];

    component lt = LessThan(k+p+1);
    lt.in[0] <== mgn_1;
    lt.in[1] <== mgn_2;

    component if_else[4];
    if_else[0] = IfThenElse();
    if_else[0].cond <== lt.out;
    if_else[0].L <== e[1];
    if_else[0].R <== e[0];
    signal e_alpha <== if_else[0].out;

    if_else[1] = IfThenElse();
    if_else[1].cond <== lt.out;
    if_else[1].L <== m[1];
    if_else[1].R <== m[0];
    signal m_alpha <== if_else[1].out;

    if_else[2] = IfThenElse();
    if_else[2].cond <== lt.out;
    if_else[2].L <== m[0];
    if_else[2].R <== m[1];
    signal m_beta <== if_else[2].out;

    if_else[3] = IfThenElse();
    if_else[3].cond <== lt.out;
    if_else[3].L <== e[0];
    if_else[3].R <== e[1];
    signal e_beta <== if_else[3].out;

    signal diff <== e_alpha - e_beta;

    component lt2 = LessThan(k+p+1);
    lt2.in[0] <== p + 1;
    lt2.in[1] <== diff;

    component is_eq = IsEqual();
    is_eq.in[0] <== e_alpha;
    is_eq.in[1] <== 0;

    component is_or = OR();
    is_or.a <== lt2.out;
    is_or.b <== is_eq.out;

    component left_shift2 = LeftShift(k+p+1);
    left_shift2.x <== m_alpha;
    left_shift2.shift <== diff;
    left_shift2.skip_checks <== 1;

    component norm = Normalize(k, p, 2*p+1);
    norm.e <== e_beta;
    norm.m <== left_shift2.y + m_beta;
    norm.skip_checks <== 1;

    component round_check = RoundAndCheck(k, p, 2*p+1);
    round_check.e <== norm.e_out;
    round_check.m <== norm.m_out;

    log(is_or.out);
    component if_else2 = IfThenElse();
    if_else2.cond <== is_or.out;
    if_else2.L <== e_alpha;
    if_else2.R <== round_check.e_out;
    e_out <== if_else2.out;

    component if_else3 = IfThenElse();
    if_else3.cond <== is_or.out;
    if_else3.L <== m_alpha;
    if_else3.R <== round_check.m_out;
    m_out <== if_else3.out;
}
