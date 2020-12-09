pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract UNICToken is IUnicToken, ERC20, Ownable {
    using SafeMath for uint256;

    uint256 public startTime;
    uint256 public MINT_CAP_UNIC_CONST = 2500000 * (10 ** 18);
    mapping(address => bool) internal _blacklistedAddresses;

    address internal _auctionAddress;
    mapping (address => bool) internal _burnerAddresses;

    modifier isBurner() {
        require(_burnerAddresses[_msgSender()], "Caller is not burner");
        _;
    }

    modifier isBlacklisted(address account) {
        require(!_blacklistedAddresses[account], "In black list");
        _;
    }

    constructor () public ERC20("UNICToken", "UNIC") {
        _burnerAddresses[_msgSender()] = true;
        startTime = now;
    }

    function getIsBlackListed(address account) external override view returns (bool) {
        if (_blacklistedAddresses[account]) {
            return true;
        }
        return false;
    }

    function setAuction(address auctionAddress) external onlyOwner {
        _auctionAddress = auctionAddress;
    }

    function isBurnAllowed(address account) external view returns(bool) {
        return _burnerAddresses[account];
    }

    function addBurner(address account) external onlyOwner {
        require(!_burnerAddresses[account], "Already burner");
        require(account != address(0), "Cant add zero address");
        _burnerAddresses[account] = true;
    }

    function removeBurner(address account) external onlyOwner {
        require(_burnerAddresses[account], "Isnt burner");
        _burnerAddresses[account] = false;
    }

    function mint(uint256 amount) public override {
        require(_msgSender() == owner() || _msgSender() == _auctionAddress, "No rights to mint");
        _mint(_auctionAddress, amount);
    }

    function burn(uint256 amount) public isBurner override {
        _burn(_auctionAddress, amount);
    }

    function addToBlacklist(address account) public onlyOwner isBlacklisted(account) {
        _blacklistedAddresses[account] = true;
    }

    function rempoveFromBlacklist(address account) public onlyOwner {
        require(_blacklistedAddresses[account], "Not blacklisted");
        delete _blacklistedAddresses[account];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override isBlacklisted(from) {}
}
