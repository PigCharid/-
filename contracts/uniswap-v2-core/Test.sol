// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract UQ112x112 {
    uint224 constant Q112 = 2**112;

    // 编码：将一个uint112的值编码为uint224
    //0000,0000000000,0000000000,0000000000,0000000000,0000000000,0000000001 => 0x01 uint112
    //00,000,000 => 前32位留空
    //0,000,000,000,000,000,000,000,000,001 => 整数部分
    //0,000,000,000,000,000,000,000,000,000 => 小数部分
    function encode(uint112 y) public pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }
    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) public pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
