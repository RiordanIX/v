module math

const two54 = f64(1.80143985094819840000e+16)
const ivln10 = f64(4.34294481903251816668e-01)
const log10_2hi = f64(3.01029995663611771306e-01)
const log10_2lo = f64(3.69423907715893078616e-13)

// log_n returns log base b of x
pub fn log_n(x f64, b f64) f64 {
	y := log(x)
	z := log(b)
	return y / z
}

// log10 returns the decimal logarithm of x.
// The special cases are the same as for log.
// log10(10**N) = N  for N=0,1,...,22.
pub fn log10(x f64) f64 {
	// https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/ieee754/dbl-64/e_log10.c

	mut x_ := x
	mut hx := i64(f64_bits(x_))
	mut k := i32(0)
	if hx < i64(0x0010000000000000) {
		// x < 2**-1022
		if hx & 0x7fffffffffffffff == 0 {
			return inf(-1) // log(+-0)=-inf
		}
		if hx < 0 {
			return (x_ - x_) / (x_ - x_) // log(-#) = NaN
		}
		k = k - 54
		x_ *= two54 // subnormal number, scale up x
		hx = i64(f64_bits(x_))
	}

	// scale up resulted in a NaN number
	if hx >= u64(0x7ff0000000000000) {
		return x_ + x_
	}

	k = k + i32((u64((hx >> 52) - 1023)))
	i := i32((u64(k) & 0x8000000000000000) >> 63)
	hx = (hx & 0x000fffffffffffff) | (u64(0x3ff - i) << 52)
	y := f64(k + i)
	/*
	if FIX_INT_FP_CONVERT_ZERO && y == 0.0 {
		y = 0.0
	}
	*/
	x_ = f64_from_bits(u64(hx))
	z := y * log10_2lo + ivln10 * log(x_)
	return z + y * log10_2hi
}

// log2 returns the binary logarithm of x.
// The special cases are the same as for log.
pub fn log2(x f64) f64 {
	frac, exp := frexp(x)
	// Make sure exact powers of two give an exact answer.
	// Don't depend on log(0.5)*(1/ln2)+exp being exactly exp-1.
	if frac == 0.5 {
		return f64(exp - 1)
	}
	return log(frac) * (1.0 / ln2) + f64(exp)
}

// log1p returns log(1+x)
pub fn log1p(x f64) f64 {
	y := 1.0 + x
	z := y - 1.0
	return log(y) - (z - x) / y // cancels errors with IEEE arithmetic
}

// log_b returns the binary exponent of x.
//
// special cases are:
// log_b(±inf) = +inf
// log_b(0) = -inf
// log_b(nan) = nan
pub fn log_b(x f64) f64 {
	if x == 0 {
		return inf(-1)
	}
	if is_inf(x, 0) {
		return inf(1)
	}
	if is_nan(x) {
		return x
	}
	return f64(ilog_b_(x))
}

// ilog_b returns the binary exponent of x as an integer.
//
// special cases are:
// ilog_b(±inf) = max_i32
// ilog_b(0) = min_i32
// ilog_b(nan) = max_i32
pub fn ilog_b(x f64) int {
	if x == 0 {
		return int(min_i32)
	}
	if is_nan(x) {
		return int(max_i32)
	}
	if is_inf(x, 0) {
		return int(max_i32)
	}
	return ilog_b_(x)
}

// ilog_b returns the binary exponent of x. It assumes x is finite and
// non-zero.
fn ilog_b_(x_ f64) int {
	x, exp := normalize(x_)
	return int((f64_bits(x) >> shift) & mask) - bias + exp
}

// log returns the natural logarithm of x
//
// Method :
//   1. Argument Reduction: find k and f such that
//                      x = 2^k * (1+f),
//         where  sqrt(2)/2 < 1+f < sqrt(2) .
//
//   2. Approximation of log(1+f).
//      Let s = f/(2+f) ; based on log(1+f) = log(1+s) - log(1-s)
//               = 2s + 2/3 s**3 + 2/5 s**5 + .....,
//               = 2s + s*R
//      We use a special Remez algorithm on [0,0.1716] to generate
//      a polynomial of degree 14 to approximate R The maximum error
//      of this polynomial approximation is bounded by 2**-58.45. In
//      other words,
//                      2      4      6      8      10      12      14
//          R(z) ~ Lg1*s +Lg2*s +Lg3*s +Lg4*s +Lg5*s  +Lg6*s  +Lg7*s
//      (the values of Lg1 to Lg7 are listed in the program)
//      and
//          |      2          14          |     -58.45
//          | Lg1*s +...+Lg7*s    -  R(z) | <= 2
//          |                             |
//      Note that 2s = f - s*f = f - hfsq + s*hfsq, where hfsq = f*f/2.
//      In order to guarantee error in log below 1ulp, we compute log
//      by
//              log(1+f) = f - s*(f - R)        (if f is not too large)
//              log(1+f) = f - (hfsq - s*(hfsq+R)).     (better accuracy)
//
//      3. Finally,  log(x) = k*ln2 + log(1+f).
//                          = k*ln2_hi+(f-(hfsq-(s*(hfsq+R)+k*ln2_lo)))
//         Here ln2 is split into two floating point number:
//                      ln2_hi + ln2_lo,
//         where n*ln2_hi is always exact for |n| < 2000.
//
// Special cases:
//      log(x) is NaN with signal if x < 0 (including -inf) ;
//      log(+inf) is +inf; log(0) is -inf with signal;
//      log(NaN) is that NaN with no signal.
//
// Accuracy:
//      according to an error analysis, the error is always less than
//      1 ulp (unit in the last place).
pub fn log(a f64) f64 {
	ln2_hi := 6.93147180369123816490e-01 // 3fe62e42 fee00000
	ln2_lo := 1.90821492927058770002e-10 // 3dea39ef 35793c76
	l1 := 6.666666666666735130e-01 // 3FE55555 55555593
	l2 := 3.999999999940941908e-01 // 3FD99999 9997FA04
	l3 := 2.857142874366239149e-01 // 3FD24924 94229359
	l4 := 2.222219843214978396e-01 // 3FCC71C5 1D8E78AF
	l5 := 1.818357216161805012e-01 // 3FC74664 96CB03DE
	l6 := 1.531383769920937332e-01 // 3FC39A09 D078C69F
	l7 := 1.479819860511658591e-01 // 3FC2F112 DF3E5244

	x := a
	if is_nan(x) || is_inf(x, 1) {
		return x
	} else if x < 0 {
		return nan()
	} else if x == 0 {
		return inf(-1)
	}

	mut f1, mut ki := frexp(x)
	if f1 < sqrt2 / 2 {
		f1 *= 2
		ki--
	}

	f := f1 - 1
	k := f64(ki)

	// compute
	s := f / (2 + f)
	s2 := s * s
	s4 := s2 * s2
	t1 := s2 * (l1 + s4 * (l3 + s4 * (l5 + s4 * l7)))
	t2 := s4 * (l2 + s4 * (l4 + s4 * l6))
	r := t1 + t2
	hfsq := 0.5 * f * f
	return k * ln2_hi - ((hfsq - (s * (hfsq + r) + k * ln2_lo)) - f)
}

// e_logf.c -- float version of e_log.c.
// e_logbf.c
// e_logb.c
// Conversion to float by Ian Lance Taylor, Cygnus Support, ian@cygnus.com.
//
//
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunPro, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================

// This specific f32 version of log is to prevent casting from f64 to f32.
// Some embedded devices can't handle 64 bit floats, in which case they can use
// the `f` variant of log.
pub fn logf(a f32) f32 {
	ln2_hi := f32(6.9313812256e-01) // 0x3f317180
	ln2_lo := f32(9.0580006145e-06) // 0x3717f7d1
	two25 := f32(3.355443200e+07) // 0x4c000000
	lg1 := f32(6.6666668653e-01) // 3F2AAAAB
	lg2 := f32(4.0000000596e-01) // 3ECCCCCD
	lg3 := f32(2.8571429849e-01) // 3E924925
	lg4 := f32(2.2222198546e-01) // 3E638E29
	lg5 := f32(1.8183572590e-01) // 3E3A3325
	lg6 := f32(1.5313838422e-01) // 3E1CD04F
	lg7 := f32(1.4798198640e-01) // 3E178897
	zero := f32(0.0)

	mut x := a
	if is_nan32(x) || is_inf32(x, 1) {
		return x
	} else if x < 0 {
		return nan32()
	} else if x == 0 {
		return inf32(-1)
	}

	mut k := i32(0)
	mut ix := f32_bits(x)
	if ix < 0x00800000 { // a < 2**-126
		if (ix & 0x7fffffff) == 0 {
			return inf32(-1)
		}
		// log(+-0)=-inf
		if ix < 0 {
			return nan32()
		}
		// log(-#) = NaN
		k -= 25
		x *= two25 // subnormal number, scale up x
		ix = f32_bits(x)
	}
	if ix >= 0x7f800000 {
		return x + x
	}
	k += i32((ix >> 23) - 127)
	ix = ix & 0x007fffff
	mut i := (ix + (0x95f64 << 3)) & 0x800000
	x = f32_from_bits(ix | (i ^ 0x3f800000)) // normalize x or x/2
	k += i32(i >> 23)
	f := x - 1.0
	mut dk := f32(0)
	if (0x007fffff & (0x8000 + ix)) < 0xc000 { // -2**-9 <= f < 2**-9
		if f == zero {
			if k == 0 {
				return zero
			} else {
				dk = k
				return dk * ln2_hi + dk * ln2_lo
			}
		}
		r := f32(f * f * (0.5 - 0.33333333333333333 * f))
		if k == 0 {
			return f - r
		} else {
			dk = f32(k)
			return dk * ln2_hi - ((r - dk * ln2_lo) - f)
		}
	}
	s := f32(f / (2.0 + f))
	dk = f32(k)
	z := f32(s * s)
	i = ix - (0x6147a << 3)
	w := f32(z * z)
	j := (0x6b851 << 3) - ix
	t1 := f32(w * (lg2 + w * (lg4 + w * lg6)))
	t2 := f32(z * (lg1 + w * (lg3 + w * (lg5 + w * lg7))))
	i = i | j
	r := f32(t2 + t1)
	if i > 0 {
		hfsq := f32(0.5 * f * f)
		if k == 0 {
			return f - (hfsq - s * (hfsq + r))
		} else {
			return dk * ln2_hi - ((hfsq - (s * (hfsq + r) + dk * ln2_lo)) - f)
		}
	} else {
		if k == 0 {
			return f - s * (f - r)
		} else {
			return dk * ln2_hi - ((s * (f - r) - dk * ln2_lo) - f)
		}
	}
}

// Included for completion's sake. Use ilogb instead if possible
pub fn logb(a f64) f64 {
	mut x := a
	mut hw := get_high_word(x)
	lw := get_high_word(f64_bits(x) << 32)
	hw &= 0x7fffffff // high |x|
	if (hw | lw) == 0 {
		return -1.0 / f64_abs(x)
	}
	if hw >= 0x7ff00000 {
		return x * x
	}
	if hw < 0x00100000 {
		x *= two54 // convert subnormal x to normal
		hw = get_high_word(x)
		hw &= 0x7fffffff
		return f64((hw >> 20) - 1023 - 54)
	} else {
		return f64((hw >> 20) - 1023)
	}
}

// Included for completion's sake. Use ilogb instead if possible
pub fn logbf(a f32) f32 {
	two25 := f32(3.355443200e+07)
	mut x := a
	mut ix := f32_bits(x)
	ix &= 0x7fffffff // high |x|
	if ix == 0 {
		return f32(-1.0) / f32_abs(x)
	}
	if ix >= 0x7f800000 {
		return x * x
	}
	if ix < 0x00800000 {
		x *= two25 // convert subnormal x to normal
		ix = f32_bits(x)
		ix &= 0x7fffffff
		return f32((ix >> 23) - 127 - 25)
	} else {
		return f32((ix >> 23) - 127)
	}
}
