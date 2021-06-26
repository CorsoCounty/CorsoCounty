// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CorsoCounty is Context, IERC20, Ownable {
    using Address for address;

