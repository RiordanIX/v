// Copyright (c) 2025 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module math

const uvnan32 = u32(0x7FC00000)
const uvinf32 = u32(0x7F800000)
const uvneginf32 = u32(0xFF800000)
const uvone32 = u32(0x3F800000)
const shift32 = 32 - 8 - 1
const normalize_smallest_mask32 = u32(u32(1) << shift32)

const frac_mask32 = u32((u32(1) << shift32) - u32(1))

// inf returns positive infinity if sign >= 0, negative infinity if sign < 0.
pub fn inf32(sign int) f32 {
	v := if sign >= 0 { uvinf32 } else { uvneginf32 }
	return f32_from_bits(v)
}

// nan returns an IEEE 754 ``not-a-number'' value.
pub fn nan32() f32 {
	return f32_from_bits(uvnan32)
}

// is_nan reports whether f is an IEEE 754 ``not-a-number'' value.
pub fn is_nan32(f f32) bool {
	$if fast_math {
		if f32_bits(f) == uvnan32 {
			return true
		}
	}
	// IEEE 754 says that only NaNs satisfy f != f.
	// To avoid the floating-point hardware, could use:
	// x := f32_bits(f);
	// return u32(x>>shift)&mask == mask && x != uvinf && x != uvneginf32
	return f != f
}

// is_inf reports whether f is an infinity, according to sign.
// If sign > 0, is_inf reports whether f is positive infinity.
// If sign < 0, is_inf reports whether f is negative infinity.
// If sign == 0, is_inf reports whether f is either infinity.
pub fn is_inf32(f f32, sign int) bool {
	// Test for infinity by comparing against maximum float.
	// To avoid the floating-point hardware, could use:
	// x := f32_bits(f);
	// return sign >= 0 && x == uvinf || sign <= 0 && x == uvneginf32;
	return (sign >= 0 && f > max_f32) || (sign <= 0 && f < -max_f32)
}

// is_finite returns true if f is finite
pub fn is_finite32(f f32) bool {
	return !is_nan32(f) && !is_inf32(f, 0)
}

// normalize returns a normal number y and exponent exp
// satisfying x == y × 2**exp. It assumes x is finite and non-zero.
pub fn normalize32(x f32) (f32, i32) {
	smallest_normal := f32(1.17549435E-38) // 2**-1022
	if f32_abs(x) < smallest_normal {
		return x * normalize_smallest_mask32, -i32(shift32)
	}
	return x, 0
}
