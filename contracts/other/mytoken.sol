// SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";


contract ProjectToken is ERC20PresetFixedSupply{
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalsuply
    )ERC20PresetFixedSupply(name,symbol,totalsuply,msg.sender){

    }

}