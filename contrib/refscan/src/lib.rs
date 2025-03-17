// SPDX-FileCopyrightText: edef <edef@edef.eu>
// SPDX-License-Identifier: MPL-2.0

use self::simd::u8x32;

fn prefilter(haystack: u8x32) -> u32 {
    let alp = haystack.gt(u8x32::splat(b'a' - 1)) & haystack.lt(u8x32::splat(b'z' + 1));
    let num = haystack.gt(u8x32::splat(b'0' - 1)) & haystack.lt(u8x32::splat(b'9' + 1));
    alp | num
}

/// scan_clean returns `Err(&buffer[..n])` of known pointer-free data,
/// or `Ok(buffer)` if the entire buffer is pointer-free.
pub fn scan_clean(buffer: &[u8]) -> Result<&[u8], &[u8]> {
    let buffer = {
        let n = buffer.len() & !31;
        &buffer[..n]
    };

    let mut masks = buffer
        .chunks_exact(32)
        .map(|chunk| prefilter(u8x32::from_slice_unaligned(chunk)))
        .enumerate()
        .map(|e| (e.0 * 32, e.1))
        .peekable();

    while let Some((offset, mask)) = masks.next() {
        let peek = masks.peek().map(|x| x.1).unwrap_or(!0 >> 1);
        let n = (!mask).leading_zeros() + (!peek).trailing_zeros();
        if n >= 32 {
            let offset = offset + mask.trailing_zeros() as usize;
            return Err(&buffer[..offset]);
        }
    }

    Ok(buffer)
}

#[cfg(test)]
mod test {
    #[test]
    fn scan_tail() {
        let buffer = b"_xfbmj7sl2ikicym9x3yq7cms5qx1w39k";
        assert_eq!(crate::scan_clean(buffer), Err(&buffer[..1]));
    }
    #[test]
    fn scan_straddle() {
        let buffer = b"________________xfbmj7sl2ikicym9x3yq7cms5qx1w39k________________";
        assert_eq!(crate::scan_clean(buffer), Err(&buffer[..16]));
    }
    #[test]
    fn scan_clean() {
        let buffer = b"x_______________xfbmj7sl2ikicym9x3yq-cms5qx1w3-k________________";
        assert_eq!(crate::scan_clean(buffer), Ok(&buffer[..]));
    }
}

#[cfg(any(target_arch = "x86", target_arch = "x86_64"))]
mod simd {
    #[cfg(target_arch = "x86")]
    use std::arch::x86 as arch;
    #[cfg(target_arch = "x86_64")]
    use std::arch::x86_64 as arch;
    use {
        arch::{__m256i, _mm256_cmpgt_epi8, _mm256_movemask_epi8, _mm256_set1_epi8},
        std::ptr,
    };

    #[allow(non_camel_case_types)]
    #[derive(Copy, Clone)]
    pub struct u8x32(__m256i);

    impl u8x32 {
        #[inline(always)]
        pub fn from_slice_unaligned(slice: &[u8]) -> Self {
            assert_eq!(slice.len(), 32);
            u8x32(unsafe { ptr::read_unaligned(slice.as_ptr().cast()) })
        }

        #[inline(always)]
        pub fn splat(x: u8) -> Self {
            u8x32(unsafe { _mm256_set1_epi8(x as i8) })
        }

        #[inline(always)]
        pub fn gt(self, b: Self) -> u32 {
            unsafe { _mm256_movemask_epi8(_mm256_cmpgt_epi8(self.0, b.0)) as u32 }
        }

        #[inline(always)]
        pub fn lt(self, b: Self) -> u32 {
            b.gt(self)
        }
    }
}

#[cfg(target_arch = "aarch64")]
mod simd {
    use std::{
        arch::aarch64::{
            uint8x16_t as u8x16, vaddv_u8, vandq_u8, vcgtq_u8, vdupq_n_u8, vget_high_u8,
            vget_low_u8, vshlq_u8,
        },
        mem, ptr,
    };

    #[allow(non_camel_case_types)]
    #[derive(Copy, Clone)]
    #[repr(transparent)]
    pub struct u8x32([u8x16; 2]);

    impl u8x32 {
        #[cfg(target_endian = "little")]
        #[inline(always)]
        pub fn from_slice_unaligned(slice: &[u8]) -> Self {
            assert_eq!(slice.len(), 32);
            u8x32(unsafe { ptr::read_unaligned(slice.as_ptr().cast()) })
        }

        #[inline(always)]
        pub fn splat(x: u8) -> Self {
            u8x32(unsafe {
                let x = vdupq_n_u8(x);
                [x, x]
            })
        }

        #[inline(always)]
        pub fn gt(&self, b: Self) -> u32 {
            let u8x32([al, ah]) = *self;
            let u8x32([bl, bh]) = b;

            fn f(a: u8x16, b: u8x16) -> u32 {
                unsafe {
                    let c = vshlq_u8(
                        vandq_u8(vdupq_n_u8(0x80), vcgtq_u8(a, b)),
                        mem::transmute([
                            -7, -6, -5, -4, -3, -2, -1, 0, -7, -6, -5, -4, -3, -2, -1, 0i8,
                        ]),
                    );

                    (vaddv_u8(vget_low_u8(c)) as u32) << 0 | (vaddv_u8(vget_high_u8(c)) as u32) << 8
                }
            }

            f(al, bl) << 0 | f(ah, bh) << 16
        }

        #[inline(always)]
        pub fn lt(self, b: Self) -> u32 {
            b.gt(self)
        }
    }
}
