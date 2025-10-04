import math

fn test_log_base() {
	assert math.log(math.e) == 1.0
	assert math.logf(math.e) == 1.0
}

fn test_log2_base() {
	assert math.log2(2.0) == 1.0
}

fn test_log10_base() {
	assert math.log10(10.0) == 1.0
	assert math.log10(0.00000000000000001) == -17.0
}

fn test_log1p_base() {
	assert math.log1p(math.e - 1) == 1.0
}

fn test_log_b_base() {
	assert math.log_b(0.0) == math.inf(-1)
	assert math.logb(0.0) == math.inf32(-1)
	assert math.logbf(0.0) == math.inf(-1)

	assert math.log_b(-1.0) == 0.0
	assert math.logb(-1.0) == 0.0
	assert math.logbf(-1.0) == 0.0

	assert math.log_b(2.0) == 1.0
	assert math.logb(2.0) == 1.0
	assert math.logbf(2.0) == 1.0

	assert math.log_b(4.0) == 2.0
	assert math.logb(4.0) == 2.0
	assert math.logbf(4.0) == 2.0

	assert math.log_b(32.0) == 5.0
	assert math.logb(32.0) == 5.0
	assert math.logbf(32.0) == 5.0
}
