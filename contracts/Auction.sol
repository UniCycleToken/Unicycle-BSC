pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract Auction is Context, Ownable {
    using SafeMath for uint256;

    INukeToken internal _nukeToken;

    constructor (address nukeTokenAddress) public {
        _nukeToken = INukeToken(nukeTokenAddress);
    }
}
