pragma solidity >= 0.6.0 < 0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces.sol";

contract CYCLEToken is ICycleToken, ERC20, Ownable {
    using SafeMath for uint256;

    address public auctionAddress;
    address public CYCLEWETHAddress;
    uint256 public CYCLEWETHLastTotalSupply;

    mapping(address => bool) private _blacklistedAddresses;

    modifier onlyAuction() {
        require(_msgSender() == auctionAddress, "Caller is not auction");
        _;
    }

    modifier onlyIfCYCLEWETHSet() {
        require(CYCLEWETHAddress != address(0), "CYCLEWETHAddress is not set");
        _;
    }

    modifier onlyIfNotBlacklisted(address account) {
        require(!_blacklistedAddresses[account], "In black list");
        _;
    }

    constructor () public ERC20("UniCycle", "CYCLE") {}

    function isBlacklisted(address account) external view override returns (bool) {
        return _blacklistedAddresses[account];
    }

    function setAuction(address auction) external override onlyOwner {
        require(auction != address(0), "Zero address");
        require(auctionAddress == address(0), "auction already set");
        auctionAddress = auction;
    }

    function setCYCLEWETHAddress(address CYCLEWETH) external override onlyOwner {
        require(CYCLEWETH != address(0), "Zero address");
        require(CYCLEWETHAddress == address(0), "CYCLEWETH already set");
        CYCLEWETHAddress = CYCLEWETH;
        CYCLEWETHLastTotalSupply = IERC20(CYCLEWETHAddress).totalSupply();
    }

    function mint(uint256 amount) external override onlyAuction onlyIfCYCLEWETHSet {
        _mint(auctionAddress, amount);
    }

    function burn(uint256 amount) external override onlyAuction {
        _burn(auctionAddress, amount);
    }

    function addToBlacklist(address account) external onlyOwner onlyIfNotBlacklisted(account) {
        _blacklistedAddresses[account] = true;
    }

    function removeFromBlacklist(address account) external onlyOwner {
        require(_blacklistedAddresses[account], "Not blacklisted");
        delete _blacklistedAddresses[account];
    }

    function sync() public {
        uint256 CYCLEWETHCurrentTotalSupply = IERC20(CYCLEWETHAddress).totalSupply();
        CYCLEWETHLastTotalSupply = CYCLEWETHCurrentTotalSupply;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        uint256 CYCLEWETHCurrentTotalSupply = IERC20(CYCLEWETHAddress).totalSupply();

        if (sender == CYCLEWETHAddress) {
            require(CYCLEWETHLastTotalSupply <= CYCLEWETHCurrentTotalSupply, "Liquidity withdrawals forbidden");
        }

        ERC20._transfer(sender, recipient, amount);

        CYCLEWETHLastTotalSupply = CYCLEWETHCurrentTotalSupply;
    }

    function _beforeTokenTransfer(address from, address, uint256) internal override onlyIfNotBlacklisted(from) {
        // solium-disable-previous-line no-empty-blocks
    }
}
