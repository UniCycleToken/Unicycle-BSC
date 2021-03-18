pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";

contract CYCLEToken is ICycleToken, ERC20, Ownable {
    using SafeMath for uint256;

    address public auctionAddress;

    modifier onlyAuction() {
        require(_msgSender() == auctionAddress, "Caller is not auction");
        _;
    }

    constructor() public ERC20("UniCycle", "CYCLE") {
        _mint(0x9ABED5AB9a29aC7340e8940E3095bF544945eEa8, 150_000 * 10**18);
    }

    function setAuction(address auction) external override onlyOwner {
        require(auction != address(0), "Zero address");
        require(auctionAddress == address(0), "auction already set");
        auctionAddress = auction;
    }

    function mint(uint256 amount) external override onlyAuction {
        _mint(auctionAddress, amount);
    }

    function burn(uint256 amount) external override onlyAuction {
        _burn(auctionAddress, amount);
    }
}
