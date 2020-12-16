pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract UNICToken is IUnicToken, ERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) internal _blacklistedAddresses;

    address internal _auctionAddress;

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

    function setAuction(address auctionAddress) external override onlyOwner {
        require(auctionAddress != 0x0000000000000000000000000000000000000000, "Zero address");
        _auctionAddress = auctionAddress;
    }

    function mint(uint256 amount) external override onlyAuction {
        _mint(_auctionAddress, amount);
    }

    function burn(uint256 amount) external override onlyAuction {
        _burn(_auctionAddress, amount);
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
