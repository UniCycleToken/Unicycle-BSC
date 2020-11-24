pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Interfaces.sol";


contract NUKEToken is INukeToken, ERC20, Ownable {
    using SafeMath for uint256;

    uint256 public startTime;
    uint256 public MINT_CAP_NUKE_CONST = 2500000000000000000000000;
    mapping(address => bool) public blacklistedAddresses;

    address internal _auctionAddress;
    address internal _owner;
    mapping (address => bool) internal _burnerAddresses;

    modifier isBurner() {
        require(_burnerAddresses[_msgSender()], "Caller is not burner");
        _;
    }

    modifier isBlacklisted(address adrs) {
        require(!blacklistedAddresses[adrs], "In black list");
        _;
    }

    constructor () public ERC20("NUKEToken", "NUKE") {
        _burnerAddresses[_msgSender()] = true;
        _owner = _msgSender();
        startTime = now;
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
        require(_msgSender() == _owner || _msgSender() == _auctionAddress, "No rights to mint");
        _mint(_auctionAddress, amount);
    }

    function burn(uint256 amount) public isBurner override {
        _burn(_auctionAddress, amount);
    }

    function addToBlacklist(address adrs) public onlyOwner isBlacklisted(adrs) {
        blacklistedAddresses[adrs] = true;
    }

    function rempoveFromBlacklist(address adrs) public onlyOwner {
        require(blacklistedAddresses[adrs], "Not blacklisted");
        delete blacklistedAddresses[adrs];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override isBlacklisted(from) {}
}
