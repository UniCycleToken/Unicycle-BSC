pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract UNICToken is IUnicToken, ERC20, Ownable {
    using SafeMath for uint256;

    // TODO start time of what?
    uint256 public startTime;

    mapping(address => bool) internal _blacklistedAddresses;

    address internal _auctionAddress;
    // TODO not needed burn\mint possible only by auction
    mapping (address => bool) internal _burnerAddresses;

    // TODO isBurner should be changed to onlyAuction, mint\burn should be available only from auction
    modifier isBurner() {
        require(_burnerAddresses[_msgSender()], "Caller is not burner");
        _;
    }

    // TODO isBlacklisted -> onlyIfNotBlacklisted, should return true if address in blacklist, overwise should be renamed (onlyIfNotBlacklisted)
    modifier isBlacklisted(address account) {
        require(!_blacklistedAddresses[account], "In black list");
        _;
    }

    constructor () public ERC20("UNICToken", "UNIC") {
        _burnerAddresses[_msgSender()] = true;
        startTime = now;
    }

    // TODO getIsBlackListed -> isBlacklisted
    function getIsBlackListed(address account) external override view returns (bool) {
        if (_blacklistedAddresses[account]) {
            return true;
        }
        return false;
    }

    // TODO require address not zero
    function setAuction(address auctionAddress) external onlyOwner {
        _auctionAddress = auctionAddress;
    }

    function isBurnAllowed(address account) external view returns(bool) {
        return _burnerAddresses[account];
    }

    // TODO not needed
    function addBurner(address account) external onlyOwner {
        require(!_burnerAddresses[account], "Already burner");
        require(account != address(0), "Cant add zero address");
        _burnerAddresses[account] = true;
    }

    // TODO not needed
    function removeBurner(address account) external onlyOwner {
        require(_burnerAddresses[account], "Isnt burner");
        _burnerAddresses[account] = false;
    }

    // TODO amount always 2,500,000 per day
    function mint(uint256 amount) public override {
        require(_msgSender() == owner() || _msgSender() == _auctionAddress, "No rights to mint");
        _mint(_auctionAddress, amount);
    }

    // TODO require _auctionAddress === msgsender
    function burn(uint256 amount) public isBurner override {
        _burn(_auctionAddress, amount);
    }

    // TODO not needed
    function addToBlacklist(address account) public onlyOwner isBlacklisted(account) {
        _blacklistedAddresses[account] = true;
    }

    // TODO not needed
    function rempoveFromBlacklist(address account) public onlyOwner {
        require(_blacklistedAddresses[account], "Not blacklisted");
        delete _blacklistedAddresses[account];
    }

    function _beforeTokenTransfer(address from, address, uint256) internal override isBlacklisted(from) {
        // solium-disable-previous-line no-empty-blocks
    }
}
