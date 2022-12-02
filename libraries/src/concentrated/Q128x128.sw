// Copied from https://github.com/FuelLabs/sway-libs/pull/32
library Q128x128;

use core::num::*;
use std::{assert::assert, math::*, revert::revert, u128::*, u256::*};

use ::I24::I24;

pub struct Q128x128 {
    value: U256,
}

pub struct msb_tuple {
    sig_bits: u64,
    most_sig_bit: u8,
}

impl Q128x128 {
    pub fn denominator() -> u64 {
        1 << 128
    }
    pub fn zero() -> Self {
        Self {
            value: U256 {
                a: 0,
                b: 0,
                c: 0,
                d: 0,
            },
        }
    }
    pub fn bits() -> u32 {
        256
    }
}
impl core::ops::Eq for Q128x128 {
    fn eq(self, other: Self) -> bool {
        self.value == other.value
    }
}
impl core::ops::Ord for Q128x128 {
    fn gt(self, other: Self) -> bool {
        self.value > other.value
    }
    fn lt(self, other: Self) -> bool {
        self.value < other.value
    }
}
impl core::ops::Add for Q128x128 {
    /// Add a Q128x128 to a Q128x128. Panics on overflow.
    fn add(self, other: Self) -> Self {
        Self {
            value: self.value + other.value,
        }
    }
}
impl core::ops::Subtract for Q128x128 {
    /// Subtract a Q128x128 from a Q128x128. Panics of overflow.
    fn subtract(self, other: Self) -> Self {
        // If trying to subtract a larger number, panic.
        assert(self.value > other.value || self.value == other.value);
        Self {
            value: self.value - other.value,
        }
    }
}
impl core::ops::Multiply for Q128x128 {
    /// Nultiply a Q128x128 by a Q128x128. Panics of overflow.
    fn multiply(self, other: Self) -> Q128x128 {
        let int = self.value * U256 {
            a: other.value.a,
            b: other.value.b,
            c: 0,
            d: 0,
        };
        let dec = self.value * U256 {
            a: 0,
            b: 0,
            c: other.value.c,
            d: other.value.d,
        } >> 128;
        Self {
            value: int + dec,
        }
    }
}
impl core::ops::Divide for Q128x128 {
    /// Divide a Q128x128 by a Q128x128. Panics if divisor is zero.
    fn divide(self, divisor: Self) -> Self {
        let int = self.value / U256 {
            a: divisor.value.a,
            b: divisor.value.b,
            c: 0,
            d: 0,
        };
        let dec = self.value / U256 {
            a: 0,
            b: 0,
            c: divisor.value.c,
            d: divisor.value.d,
        } << 128;
        Self {
            value: int + dec,
        }
    }
}
impl Q128x128 {
    fn insert_sig_bits(ref mut self, msb_idx: u8, log_sig_bits: u64) -> U256 {
        // intiialize vector
        let mut v = Vec::new();
        v.push(self.value.a);
        v.push(self.value.b);
        v.push(self.value.c);
        v.push(self.value.d);
        let mut result_idx = 63;

        // match msb_idx (most significant bit index) with vector_idx
        let start_vector_idx = (v.len() - 1) - (msb_idx) / 64;
        let mut vector_idx = start_vector_idx;

        // iterate over vector
        while (vector_idx < v.len()) {
            // initialize bit_idx
            let mut bit_idx = if vector_idx == start_vector_idx {
                msb_idx % 64
            } else {
                63
            };
            // iterate over each bit in each vector element
            while (bit_idx > 0) {
                // take the new bit from log_sig_bits and scale it to current bit_idx
                let new_bit = log_sig_bits & (1 << result_idx) >> result_idx << bit_idx;
                // replace old bits with new
                let new_value = v.get(vector_idx).unwrap() + new_bit;
                v.set(vector_idx, new_value);
                // return when all 64 bits have been inserted
                if (result_idx == 0) {
                    return U256 {
                        a: v.get(0).unwrap(),
                        b: v.get(1).unwrap(),
                        c: v.get(2).unwrap(),
                        d: v.get(3).unwrap(),
                    };
                }
                result_idx -= 1;
            }
            vector_idx += 1;
        }
        U256 {
            a: 0,
            b: 0,
            c: 0,
            d: 0,
        }
    }
}

impl Q128x128 {
    /// Creates Q128x128 that correponds to a unsigned integer
    pub fn from_uint(uint: u64) -> Q128x128 {
        let value = U256 {
            a: 0,
            b: uint,
            c: 0,
            d: 0,
        };
        Q128x128 { value }
    }

    /// Creates Q128x128 that correponds to a unsigned integer
    pub fn from_u128(uint128: U128) -> Q128x128 {
        let value = U256 {
            a: uint128.upper,
            b: uint128.lower,
            c: 0,
            d: 0,
        };
        Q128x128 { value }
    }

    /// Creates Q128x128 that correponds to a unsigned integer
    pub fn from_u256(uint256: U256) -> Self {
        let value = uint256;
        Self { value }
    }

    pub fn from_q64x64(q64: U128) -> Q128x128 {
        let value = U256 {
            a: 0,
            b: q64.upper,
            c: q64.lower,
            d: 0,
        };
        Q128x128 { value }
    }

    // Returns the log base 2 value
    pub fn binary_log(ref mut self) -> I24 {
        // find the most significant bit
        let msb_idx = most_sig_bit_idx(self.value);
        return I24 {underlying: msb_idx};

        // find the 64 most significant bits
        let sig_bits: u64 = most_sig_bits(self.value, msb_idx);
        // assert(sig_bits != 0);

        // take the log base 2 of sig_bits
        // let log_sig_bits = log2(sig_bits);
        let log_sig_bits = sig_bits.log(2);
        return I24 {underlying: 0};
        // reinsert log bits into Q128x128
        let log_base2_u256 = self.insert_sig_bits(msb_idx, log_sig_bits);
        let log_base2_q128x128 = Q128x128 {
            value: log_base2_u256,
        };

        // log2(10^128) + 8*log2(10^16)
        let ten_to_the_16th: u64 = 10000000000000000;
        let log_base2_max_u64 = ten_to_the_16th.log(2);

        // log2(10^128) = 8 * log2(10^16)
        let log_base2_1_q128x128 = Q128x128 {
            value: U256 {
                a: 0,
                b: 0,
                c: 0,
                d: (log_base2_max_u64 * 8),
            },
        };
        let mut tick_index: I24 = I24::from_uint(0);

        if log_base2_q128x128 > log_base2_1_q128x128 {
            let log_base2_value = log_base2_q128x128 - log_base2_1_q128x128;
            tick_index = I24::from_uint(log_base2_value.value.b);
        } else {
            let log_base2_value = log_base2_1_q128x128 - log_base2_q128x128;
            tick_index = I24::from_neg(log_base2_value.value.b);
        }
        tick_index
    }       
}

pub fn most_sig_bit_idx(value: U256) -> u64 {
    let mut v = Vec::new();
    v.push(value.a);
    v.push(value.b);
    v.push(value.c);
    v.push(value.d);

    let mut vector_idx = 0;
    while vector_idx < v.len() {
        let mut bit_idx = 64;
        while (bit_idx > 0) {
            bit_idx -= 1;
            let bit_compare = 1 << bit_idx;
            // return v.get(vector_idx).unwrap()
            if (v.get(vector_idx).unwrap() > bit_compare
                || v.get(vector_idx).unwrap() == bit_compare)
            {   
                return 64 * (v.len() - vector_idx - 1) + (bit_idx);
            }
        }
        vector_idx += 1;
    }
    //TODO: should throw err
    return 0;
}

/// 32/32
/// 0x00000000ffffffff/0xffffffff00000000
/// 1.0001
/// log (1) = 0
/// log base 2 (1.0001) = 0.xxx

pub fn most_sig_bits(value: U256, msb_idx: u8) -> u64 {
    let value_idx = msb_idx / 64;
    let msb_mod   = (msb_idx + 1) % 64;

    let first_val: u64 = 0; let second_val: u64 = 0;

    let first_val = match value_idx {
        0 => value.d,
        1 => value.c,
        2 => value.b,
        3 => value.a,
        _ => return 0,
    };

    if msb_mod == 0 || value_idx == 0 {
        return first_val;
    }

    let second_val = match value_idx {
        1 => value.d,
        2 => value.c,
        3 => value.b,
        _ => return 0,
    };

    // example: msb_mod = 31
    let lsh_first_val = first_val << (64 - msb_mod);    

    //let mask_second_val = 2 ** (msb_mod) - 1 << (64 - msb_mod);
    // return mask_second_val;
    //let masked_second_val = second_val & mask_second_val;

    let rsh_second_val = second_val >> (msb_mod);

    (lsh_first_val + rsh_second_val)
}
