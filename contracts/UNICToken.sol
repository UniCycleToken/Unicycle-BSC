pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract UNICToken is IUnicToken, ERC20, Ownable {
    using SafeMath for uint256;

    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    mapping(address => bool) internal _blacklistedAddresses;

    address internal _auctionAddress;
    uint256 internal _startTime;

    modifier onlyAuction() {
        require(_msgSender() == _auctionAddress, "Caller is not auction");
        _;
    }

    modifier onlyIfNotBlacklisted(address account) {
        require(!_blacklistedAddresses[account], "In black list");
        _;
    }

    constructor () public ERC20("UNICToken", "UNIC") {}

    function isBlacklisted(address account) external view override returns (bool) {
        if (_blacklistedAddresses[account]) {
            return true;
        }
        return false;
    }

    function setStartTime(uint256 startTime) external onlyAuction override {
        _startTime = startTime;
    }

    function getStartTime() external override returns (uint256){
        return _startTime;
    }

    function mint(uint256 amount) public override onlyAuction {
        // require(now > _startTime.add(86400));
        require(balanceOf(_auctionAddress) == 0, "Auction balance must be 0");
        _mint(_auctionAddress, amount);
    }

    function burn(uint256 amount) public override onlyAuction {
        _burn(_auctionAddress, amount);
    }

    function setAuction(address auctionAddress) external override onlyOwner {
        require(auctionAddress != ZERO_ADDRESS, "Zero address");
        _auctionAddress = auctionAddress;
    }

    function addToBlacklist(address account) public onlyOwner onlyIfNotBlacklisted(account) {
        _blacklistedAddresses[account] = true;
    }

    function rempoveFromBlacklist(address account) public onlyOwner {
        require(_blacklistedAddresses[account], "Not blacklisted");
        delete _blacklistedAddresses[account];
    }

    function _beforeTokenTransfer(address from, address, uint256) internal override onlyIfNotBlacklisted(from) {
        // solium-disable-previous-line no-empty-blocks
    }
}
